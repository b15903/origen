require 'colored'
module Origen
  class ChipPackageViewer
    PIN_METHODS = [:pins, :power_pins, :ground_pins, :virtual_pins]

    attr_accessor :number_of_rows
    attr_accessor :number_of_columns
    attr_accessor :interconnects
    attr_accessor :types
    attr_reader :jedec_rows
    attr_reader :upper_axes
    attr_reader :lower_axes
    attr_reader :rows
    attr_reader :columns
    attr_reader :field
    attr_reader :obj
    attr_reader :groups
    attr_reader :group_list
    attr_reader :last_empty_char
    attr_reader :plottable
    attr_reader :current_pkg

    def initialize(pkg, options = {})
      options = {
        view: :plot
      }.merge(options)
      @current_pkg = pkg
      case options[:view]
      when :plot
        prepare_plot
      else
        Origen.log.warn 'No other package veiws available currently, set options[:view] to :plot'
        exit 0
      end
    end

    def types
      @types || []
    end

    #  prepare_plot should not need to be called explicitly. It is called
    #  by other methods when need-be, and is fundamentallyis responsible
    #  for two things:
    #
    #    1. It checks that self.types includes a "BGA" option.
    #    2. It populates the .field attribute with a multi-dimensional
    #       array, proportional in size to the package BGA.
    #
    def prepare_plot
      @jedec_rows = init_jedec_rows
      @number_of_columns = init_columns
      @last_empty_char = '.'
      @field = []
      @groups = []
      @group_list = list_groups
      @columns = []
      @number_of_rows.times { @field.insert(0, []); @number_of_columns.times { @field[0].insert(0, []) } }
      @rows = @jedec_rows[0, @number_of_rows]
      (1..@number_of_columns).map { |item| @columns << item }
      @upper_axes = []
      @lower_axes = []
      @columns.each_with_index do|column, index|
        # if index % 2 == 0
        if index.even?
          temp = column.to_s
          temp += ' ' unless temp.size > 1
          @upper_axes << temp
          @lower_axes << '  '
        else
          temp = column.to_s
          temp += ' ' unless temp.size > 1
          @lower_axes << temp
          @upper_axes << '  '
        end
      end
    end

    #  generate_field should not need to be called explicitly. It is called
    #  by other methods when need-be, and is fundamentallyis responsible
    #  for two things:
    #
    #    1. It fills the .field array with the appropriate symbols/markers.
    #    2. It concatenates the array elements into printable rows, and prints
    #       them.
    #
    def generate_field(emptyChar = @last_empty_char)
      if plottable
        new_field = []
        @field.each do |rows|
          rows.each do |items|
            if items.length == 0
              items.insert(0, "#{emptyChar} ")
            elsif emptyChar != @last_empty_char && items == ["#{last_empty_char} "]
              items[0] = "#{emptyChar} "
            end
          end
          new_field.insert(-1, rows.join(''))
        end
        @last_empty_char = emptyChar
        package = (owner.package.nil?) ? 'No package chosen.' : owner.package.to_s
        puts "\nPin field: #{package}\n\n"
        group_display = @groups.join("\n")
        puts "Legend: \n#{group_display}\n\n"
        puts @upper_axes.join('').yellow
        new_field.each_with_index { |line, index| puts line + "#{@rows[index]} (#{index + 1})\n".chop.yellow }
        puts @lower_axes.join('').yellow, "\n"
      end
    end
    alias_method :show, :generate_field

    def add_power(marker = 'P')
      # add_power can be called explicitly or by the .plot("power") method call.
      prepare_plot if field.nil?
      if plottable
        pin_list = owner.power_pins.map { |_ken, pin| pin }
        @groups << "#{marker} - Power"
        pin_list.each do |item|
          # puts items,owner.pins[items].location
          begin
            coordinates = coordinate(item.location)
            @field[coordinates[0]][coordinates[1]] = [marker.red + ' ']
          rescue
            puts "#{item} doesn't appear to have a physical location in this configuration."
            puts "Current package = #{owner.package}"
          end
        end
        generate_field
      end
    end
    alias_method :add_powers, :add_power
    alias_method :plot_power, :add_power
    alias_method :plot_powers, :add_power

    def add_grounds(marker = 'G')
      # add_grounds can be called explicitly, or by the .plot("grounds") method call.
      prepare_plot if field.nil?
      if plottable
        pin_list = owner.ground_pins.map { |_ken, pin| pin }
        @groups << "#{marker} - Ground"
        pin_list.each do |item|
          begin
            coordinates = coordinate(item.location)
            @field[coordinates[0]][coordinates[1]] = [marker.green + ' ']
          rescue
            puts "#{item} doesn't appear to have a physical location in this configuration."
          end
        end
        generate_field
      end
    end
    alias_method :add_ground, :add_grounds
    alias_method :plot_ground, :add_grounds
    alias_method :plot_grounds, :add_grounds

    def clear
      # clear removes all elements from the .field and .groups attributes.
      prepare_plot if field.nil?
      if plottable
        @groups = []
        @field = []
        @number_of_rows.times { @field.insert(0, []); @number_of_columns.times { @field[0].insert(0, []) } }
      end
    end

    def plot_help
      prepare_plot if field.nil?
      puts "\n#################### PLOT HELP ####################"
      puts 'To generate in-console BGA plots, the ChipPackage class will respond to the following methods:'
      puts '.list_groups, .plot(), .plot_coord(), .show(), and .clear'
      if plottable
        puts "\nPLOTTING GROUPS:"
        puts '$dut.package.list_groups <-- to see available group names'
        puts "$dut.package.plot(\"ddr_interface_1\")"
        puts "$dut.package.plot_group(\"serdes_1\",'Z') <--denotes custom legend marker, Z"
        puts "\nPLOTTING INDIVIDUAL PINS:"
        puts "$dut.package.plot(\"d1_mdqs00\")"
        puts "\nPLOTTING WITH REGEXP:"
        puts "$dut.package.plot(\"d1_mdqs\") <-- Plot all controller 1 DQS pins."
        puts "$dut.package.plot(\"d1_mdqs0[0-9]\") <-- Plot d1_mdqs00 - d1_mdqs09."
        puts "\nADDING POWER/GROUND:"
        puts "$dut.package.plot(\"grounds\")"
        puts "$dut.package.plot(\"power\")"
        puts "\nVIEW CURRENT PLOT\n"
        puts '$dut.package.show'
      else
        puts 'Currently, only BGA package types are supported for in-console plotting.'
      end
    end
    alias_method :help_plot, :plot_help

    def list_groups
      # returns an array of group names assigned to the package
      grps = owner.pins.map { |_key, val| val.group }
      grps.uniq!
    rescue
      return []
    end
    alias_method :group_list, :list_groups

    def group_array(grp)
      # returns an array of pins belonging to the given group
      pin_list = $dut.pins.map { |_key, val| val if val.group == grp }
      pin_list[0].compact!
      puts 'No pins found under that group name.' unless pin_list.any?
    rescue
      return []
    end

    # ##############################################################
    # ############# String/Coordinate Manipulation #################
    # ##############################################################

    def coordinate(location)
      ## Returns array of numerical equiv coordinates (e.g. "AA11" -> [20,11])
      error = "\n\nSomething wrong during coordinate-mapping.\nAre you sure you passed an alphanumeric string\n to the coordinate() method?\n"
      split_index = -1
      location.each_char do |character|
        if letter?(character)
          split_index += 1
        end
      end
      row = location[0..split_index]
      column = location[split_index + 1..-1]
      fail ArgumentError, error unless row.length > 0 && column.length > 0
      ## Now convert alphanumeric row to jedec equiv' with to_row() method
      # and return coordinates.
      coordinates = [to_row(row), column.to_i - 1]
    end

    def to_row(alphanumeric_coord)
      ## This maps alpha row coordinate to its appropriate Jedec:
      number = alphanumeric_coord.upcase.tr('A-HJ-NPRT-WY', '1-9a-q').to_i(21) - 1
      number -= (number / 21)
    end

    def letter?(test_character)
      ## Returns nil if the 'test_character' isn't a letter.
      test_character =~ /[[:alpha:]]/
    end

    def initial(test_string)
      test_string[0, 1]
    end

    #  .plot can be called explicitly and accepts string arguments with
    #  or without regex styling. For example:
    #
    #    $dut.package = :t4240
    #    $dut.package.plot("ddr_interface") # plots all "ddr interface" groups
    #    $dut.package.plot("grounds") # adds ground pins to the previously instantiated plot
    #    $dut.package.plot("d1_mdq37","$") # plots controller 1 mdq 37, and uses $ as a legend marker
    #    $dut.package.plot("d2_mdq[3-6]0) # plots d2_mdq30, d2_mdq40, d2_md520, and d2_md620
    #
    def plot(pinName, marker = nil)
      prepare_plot if field.nil?
      if plottable && pinName.is_a?(String) && /ground/ =~ pinName.downcase
        add_grounds('G')
      elsif plottable && pinName.is_a?(String) && /power/ =~ pinName.downcase
        add_power('P')
      elsif plottable && pinName.is_a?(String)
        found_pins = []
        owner.pins.map { |pin| found_pins << pin[1] if /#{pinName}/ =~ pin[1].name.to_s || /#{pinName}/ =~ pin[1].group.to_s }
        if found_pins.size == 1 && marker.nil?
          marker = initial(pinName.to_s)
          while @groups.index { |grpName| grpName =~ /#{marker} -/ }
            marker.next!
            marker = '0' unless marker.size < 2
          end
          coordinates = coordinate(found_pins[0].location)
          @field[coordinates[0]][coordinates[1]] = [marker.white_on_blue + ' ']
          @groups.delete_if { |group| /#{pinName.to_s}/ =~ group }
          @groups << "#{marker} - #{found_pins[0].name} - #{found_pins[0].location}"
        elsif found_pins.size == 1
          coordinates = coordinate(found_pins[0].location)
          @field[coordinates[0]][coordinates[1]] = [marker.white_on_blue + ' ']
          @groups.delete_if { |group| /#{pinName.to_s}/ =~ group }
          @groups << "#{marker} - #{found_pins[0].name} - #{found_pins[0].location}"
        else
          if marker.nil?
            marker = initial(pinName.to_s)
            while @groups.index { |grpName| grpName =~ /#{marker} -/ }
              marker.next!
              marker = '0' unless marker.size < 2
            end
          end
          reg_state = quote_regex(pinName)
          found_pins.each do |item|
            begin
              coordinates = coordinate(item.location)
              @field[coordinates[0]][coordinates[1]] = [marker + ' ']
              @groups.delete_if { |group| "#{marker} - \"#{reg_state}\"" == group }
              @groups << "#{marker} - \"#{pinName}\""
            rescue
              raise "\n#{item} doesn't appear to have a physical location in this configuration."
            end
          end
        end
        generate_field
      else
        puts 'Unsupported argument type.'
      end
    end

    #  .plot_coord can be called explicitly and accepts string arguments in the form
    #  of jedec standard BGA coordinate naming conventions.
    #
    #    $dut.package = :t4240
    #    $dut.package.plot_coord("A2")
    #
    def plot_coord(coord, marker = nil)
      prepare_plot if field.nil?
      if plottable
        if coord.is_a?(String)
          found_pins = []
          owner.pins.map { |pin| found_pins << pin[1] if coord == pin[1].location.to_s }
          if marker.nil?
            marker = initial(coord.to_s)
            while @groups.index { |grpName| grpName =~ /#{marker} -/ }
              marker.next!
              marker = '0' unless marker.size < 2
            end
            found_pins.each do |pin|
              coordinates = coordinate(pin.location)
              @field[coordinates[0]][coordinates[1]] = [marker.white_on_blue + ' ']
              @groups.delete_if { |group| /#{coord.to_s}/ =~ group }
              @groups << "#{marker} - #{found_pins[0].name} - #{found_pins[0].location}"
            end
          else
            coordinates = coordinate(found_pins[0].location)
            @field[coordinates[0]][coordinates[1]] = [marker.white_on_blue + ' ']
            @groups.delete_if { |group| /#{coord.to_s}/ =~ group }
            @groups << "#{marker} - #{found_pins[0].name} - #{found_pins[0].location}"
          end
          if found_pins.size > 0
            generate_field
          else
            puts "Coordinate not recognized. Jedec convention: <row><col>. E.g., A1.\nCould be power/ground pin. .plot(\"power\") or .plot(\"ground\")."
          end
        else
          puts 'Unsupported argument type.'
        end
      end
    end
    alias_method :plot_coordinate, :plot_coord

    def quote_regex(regex_statement)
      with_escapes = regex_statement
      with_escapes.gsub!('[', '\[')
      with_escapes.gsub!(']', '\]')
      with_escapes.gsub!('^', '\^')
      with_escapes
    end

    def plot_ceo
      scramble = ['         +....~~~~~:,,..::~~:,......,:~==~,,....,:~==~~::,:~~,.,               ',
                  '            ...++~:,,:~~~~~======~::::,,,,::=======~~::,,                      ',
                  '.................????????+,,,,::::::,,,.,,..,,,,:::????......................:+',
                  '           ,.,:~~~~~:,~~~~:~:~~=~:~~~==++====::~~~===~~=~~==:,,                ',
                  '         ,....~++?:::,,::::~~~=======+============~~~:,~                       ',
                  '           ....+++,:,,::::~~~==========~===========~:,:,~                      ',
                  '           ,........~~~~~~============================~........:               ',
                  '        ......,~~~~~~~===~++==+=+++++++++++++++++====~===~~~.....~             ',
                  '                ,,,::::::~~~~:,,:::,,,,:,,,,......:~~:~::,,:                   ',
                  '        .....,::~~~~=============+++++++++++++++++=======~~~:.....             ',
                  '               +.,::::::~~~=~=~~~~~~~====~~~~~:::~~==~~::::,                   ',
                  '          .......:~~~~=~=======++++++++++++++++++======~~........              ',
                  '           +:,,::~===+++++====+====~~~=====~====+++++++++=~~,~+                ',
                  '.....................,===+???????    ,..........????????=:,....................',
                  '...................=????????++++:,::::::::::::::???????~.......................',
                  '......................+++++??????   .............=??????+:,....................',
                  '                     =~:,::~~++=~=::,,,,,,,,,:                                 ',
                  '              +.........,,,,,,...,,,:,,,........,,,........,?                  ',
                  '         :....::~~~=========+++++++++++++++++++++++=======~~:....              ',
                  '...................,+???????????? ?::,:,,,,,,::????????=,......................',
                  '..................~???????++++,::,::::::~~:::::::+?????:.......................',
                  '        :......:~~~~~~~=====+++++++++++++++++++++=+=====~~~......=             ',
                  '             ::,::::~~===++===:.,~~~~~~===~~~~~,,:======~~::,                  ',
                  '               ,,,::::~~~~~~~~~=~~===~~~~===~=====~~~~~~:::,~                  ',
                  '....................::~+???????         =~+     ?????+?+=,.....................',
                  '          :,.,~~~~~,:~~~......~,,..:~=+++=~:,..:,.......:~~=~:,~               ',
                  '            :........:~~~~~~~~~===============~~~====:,.......                 ',
                  '            ::,::~~===+++++++++==~~~~=======~~====+++++==~~:::                 ',
                  '         ....,:~~~~~========++++++++++++++++++++++=+=====~~~:....              ',
                  '         ,......,~~~~~~~=======+++++++++++++++++++=====~~~.......              ',
                  '      ,........+???~:::,,,,,:~~~~==============~~~~:,,?...?                    ',
                  '          ...,~~~~~,.,~=====~:,.,.,:~==+==:,,,,.,,.,,~==~::=~,,~               ',
                  '             ,........,:::::,:::::~~~~~~~:::,,,,,,~::.......,=                 ',
                  '             ::,::~:~~======~:.,~::,,,,,,,,,,,~=.,:~===~~~::,                  ',
                  '.........................???++?????====.........?????~,??+::,..................',
                  '        ......:~:~~~=~=========+=++++++++++++++++=======~~~~:.....             ',
                  '                   ,...,..,.,,.,,,,,,.:::,.,,........?                         ',
                  '.......................?++???      ...............??????+::....................',
                  '...........................?+?????   ??~....,...+?????????=::..................',
                  '        ......:~:~~~~~====~======~==++===+++++===========~~~.....~             ',
                  '..........................+????? ?????+=........??????????~::..................',
                  '          ....::~~~====+++++=======++++++++++==============~:...~              ',
                  '..........................?+?????? ?++=,........????????~+:::..................',
                  '         .......:~~~~~~======+++++++++++++++++++++=====~~~:......              ',
                  '.......................~??????   :.......,.........??????~:,...................',
                  '               ,,:::::~~=~~~:,~=~~~~~~:~~~~~~~====:~~=~~:::::                  ',
                  '              ~,,:::::~=====:..~~~,.,:,,.,,,.~==~,:~===~~::,:=                 ',
                  '                    :,....::::,:,,,,,,,.,,,,,,..,:=                            ',
                  ' ..............+?????=,,,,::,,,::~:~~~~~~~~~:::::,,::??..........~             ',
                  '           ,,.:~~====~~~==~=~~~=====~~==+======~~~~~~===~===:,:                ',
                  '          ........~~~~~======+++++++++++++++++++=======~~.......               ',
                  '          ....::~~~~===============================~~~:~===~:...               ',
                  '               ,...........,...................,..........:                    ',
                  '         +....:~~~~~~~,,..,,,,,.,:~~~~~===~~~~:,.,,,,,,,:~~~~..,               ',
                  '        .......~~~~~~~~=~==+==+++++++++++++=++++++==~====~~,.....:             ',
                  '.................~???????+++,,,:,::::::,,,,,:,:::,?????........................',
                  '           ~,.,:~==================~~~==+==~=========++++==~:::                ',
                  '                 ,....,,,,,......,,,.,..:,:,..........:~                       ',
                  '........................??????  ++=.,,:.........++=:?????=::...................',
                  '        .......+++?:~:,,,,::~~~==================~~~:,,.?                      ',
                  '...................,:+?????????????? =:~:::::~ ???????++:......................',
                  '        :....,::~~~~==~====+=+++++++++==+++++++++========~~~:....:             ',
                  '.....................~~~+??????        ~:....:  ????????=:.....................',
                  '....................::+?????????????????::,.  ????????++~......................',
                  '                ,...,,:,.,................,,::..........,=                     ',
                  '            ~::,:~~~====+++++==~:~~~~==++===~=::~==++++==:::,:                 ',
                  '          ~,.,~~~~~~~,..:~...~=~::,~~=++++=~~::~~~~~~:,,,~==~:,                ',
                  '........................~??????=+?+~:~~.........???..????=::...................',
                  '    ,..........+????:::,::,,,:~~~~~~==~~~~~~~~~~~~,.:=?......:                 ',
                  '................=???????~,,,::,:,:,,,.......,,,,,,:~???..................=     ',
                  '               ,,::::::~~~~~~~~~~=====~~~~=====~~~~=~~~::::,                   ',
                  '           ........~~~~~========+++++++==++++=========~~........               ',
                  '             :..+,,,:~~~~~======~~~==~===~~~~======~~~:::,                     ',
                  '               ~.,,::~:~~~~~~~~~~~~~~~=======~=====~~~~::,:                    ',
                  ' ..............:??????+,,,,:,,,,:,,,,,,,,....,..,,::~??..............,         ',
                  '                 .,:~~:~:::::.....,:~=====~:::~~~:,::~~::,,                    ']
      pw = [16, 47, 75, 168, 53, 36, 57, 116, 94, 21, 64, 52, 13, 95, 1, 17, 32, 38, 4, 142,
            26, 6, 89, 134, 44, 71, 50, 40, 170, 149, 11, 29, 167, 27, 120, 43, 21, 107, 72, 14, 54,
            7, 3, 58, 55, 39, 35, 47, 113, 5, 9, 61, 162, 123, 39, 28, 18, 36, 35, 91, 41, 51, 160,
            128, 54, 53, 0, 138, 165, 125, 31, 25, 19, 155, 25, 66, 3, 15, 49, 96, 49, 56, 158, 100,
            147, 12, 27, 101, 56, 12, 65, 22, 124, 106, 11, 33, 46, 26, 103, 7, 45, 23, 46, 97, 9,
            70, 10, 109, 119, 22, 8, 75, 151, 65, 52, 73, 72, 99, 30, 17, 1, 5, 90, 76, 81, 4, 59,
            50, 82, 84, 30, 68, 102, 148, 80, 48, 74, 129, 137, 132, 69, 2, 140, 34, 144, 55, 20,
            150, 24, 143, 14, 19, 86, 8, 67, 60, 63, 2, 62, 146, 24, 62, 0, 104, 68, 13, 15, 173, 79,
            63, 37, 44, 93, 85, 60, 58, 67]
      y = []
      (0..71).each { |n| y << n + n / 2 * 3 }
      y.each do |z|
        puts scramble[pw[z]]
      end
      'Oh, hello!'
    end

    private

    def init_jedec_rows
      @jedec_rows = []
      @current_pkg.owner.package = @current_pkg.id
      if uniq_locns.empty?
        Origen.log.error "Cannot view the '#{@current_pkg.id}' package, no pins with package location found!"
        fail
      end
      @jedec_rows += uniq_locns.select { |locn| locn.match(/^[A-Z]\d+$/) }.map { |locn| locn[0] }.uniq.sort
      @jedec_rows += uniq_locns.select { |locn| locn.match(/^[A-Z][A-Z]\d+$/) }.map { |locn| locn[0..1] }.uniq.sort
    end

    def init_columns
      @columns = []
      @current_pkg.owner.package = @current_pkg.id
      if uniq_locns.empty?
        Origen.log.error "Cannot view the '#{@current_pkg.id}' package, no pins with package location found!"
        fail
      end
      @columns = uniq_locns.select { |locn| locn.match(/^[A-Z]+(\d)$/) }.map { |locn| locn.match(/^[A-Z]+(\d)$/)[1].to_i }.uniq.sort
      @columns += uniq_locns.select { |locn| locn.match(/^[A-Z]+(\d\d)$/) }.map { |locn| locn.match(/^[A-Z]+(\d\d)$/)[1].to_i }.uniq.sort
    end

    def uniq_locns
      [].tap do |ary|
        PIN_METHODS.each do |m|
          pins_with_locn = @current_pkg.owner.send(m).reject { |id, obj| obj.meta[:location].nil? }
          ary << pins_with_locn.map { |id, obj| obj.meta[:location] }
        end
      end.flatten
    end
  end
end

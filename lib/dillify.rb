#require "dillify/version"

class Dillify

# -------------------------------------------------------------
# Notes
# - I use tag prefixes so I can run individual scenarios that have numbered tags
# ex. @dill.01, @dill.02 will both be caught by @dill
# -------------------------------------------------------------

  def run
    verify_cucumber_project
    setup
    run_tags
  end

  def verify_cucumber_project
    unless File.exists? 'features'
      puts "#{color('r','Error:')} #{color('b','dillfy')} must be run in a #{color('b','cucumber')} project (have a '#{color('b','features')}' folder)"
      abort
    end
  end

  # Setup
  def setup(args=nil)
    @question_repeat = 3
    @os_windows = (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
    @os_mac = (/darwin/ =~ RUBY_PLATFORM) != nil
    @os_linux = !@os_windows && !@os_mac

    #Ask questions if necessary
    @project_directory = Dir.pwd
    @log_folder_name = 'dillify'
    #@generic_heatmap = false

    #Create log folder/files
    ask_log_folder_name if @log_folder_name.nil?
    create_log_folder
    name_log_files

    ask_tag_questions if @tag_prefixes_to_run.nil? unless re_run_non_passed?
    collect_tags_from_directory
    ask_generic_heatmap if @generic_heatmap.nil?
  end
  def directory_help
    unless @windows
      array = @project_directory.split('/')
      array.each.with_index do |item,index|
        next if index == 0
        dir = array[0,index + 1].join('/')

        unless File.directory?(dir)
          dir = array[0,index].join('/')
          puts "Valid folders in path #{dir}:"
          puts `cd #{dir}; ls`
          break
        end
      end
    end

  end
  def ask_log_folder_name
    print "Name a log folder(default 'dillify'): "
    @log_folder_name = STDIN.gets.chomp.strip
    @log_folder_name = 'dillify' if @log_folder_name == ''
    #puts @log_folder_name
  end
  def ask_tag_questions
    print "List important starts of tags, separated by commas (Starting with @): "
    @tag_prefixes_to_run = question_separated_by_commas
    #print "#{@tag_prefixes_to_run}\n"
    if @tags_to_skip.nil?
      print "Are there any tags you would like to skip?(y/n): "
      if question_yes_no
        print 'List tags to skip separated by commas: '
        @tags_to_skip = question_separated_by_commas
        #print "#{@tags_to_skip}\n"
      end
    end
  end
  def ask_generic_heatmap
    print "Do you want the steps in the summary generalized?(y/n): "
    @generic_heatmap = question_yes_no
  end
  def create_log_folder
    @log_directory = File.join(@project_directory,@log_folder_name)
    return if File.directory?(@log_directory)
    Dir::mkdir(@log_directory)
    #puts @log_directory
  end
  def name_log_files
    summary = "dillify-summary.txt"
    failure = "dillify-fail-#{time}.txt"
    @summary_log_path = File.join(@log_directory,summary)
    @failure_log_path = File.join(@log_directory,failure)
  end
  def re_run_non_passed?
    history = get_tags_from_last_summary
    unless history.any? #If never run or all tests were previously passed
      archive_last_summary
      return false
    end
    print "Would you like to rerun the #{history.length} unpassed tags?(y/n): "
    response = question_yes_no

    if response
      @tags = history
    else
      archive_last_summary
    end
    return response
  end

  #Previous Summary
  def get_tags_from_last_summary
    return [] unless File.exists? @summary_log_path
    File.open(@summary_log_path, 'r') {|f| @old_summary = f.read }
    parsed = parse_summary_lines
    non_passed = parsed[0] - parsed [1]
    failed = parsed[2] - parsed[1]
    non_passed_failed_last = non_passed - failed + failed
    non_passed_failed_last
  end
  def parse_summary_lines
    array, line_array = [[],[],[]] , ['','','']

    @old_summary.each_line do |line|
      line_array[0] += line if line.start_with? 'Scheduled'
      line_array[1] += line if line.start_with? 'Passed'
      line_array[2] += line if line.start_with? 'Failed'
    end

    line_array.each_with_index do |item,index|
      item.each_line do |line|
        item = line.strip.gsub(']','').gsub('"','').gsub(' ','').split('[')[1]
        item = item.split(',')if line.include? ','
        array[index] << item
        array[index] = array[index].flatten.uniq
      end
    end
    array
  end
  def archive_last_summary
    archive_name = "atf-summary_before-#{time}.txt"
    if File.exists? @summary_log_path
      File.open(File.join(@log_directory,archive_name), 'w') {|f| f.write(@old_summary)}
      @old_summary = ''
      File.delete(@summary_log_path)
    end
  end

  #Gather tags from feature files
  def collect_tags_from_directory
    return if @tags.any? if !!@tags #skip if collected from summary
    @tags = []
    features = find_feature_files(File.join(@project_directory,'features',''))
    features.each do |feature|
      @tags << scan_features_for_tags(feature)
      @tags.flatten!.uniq!
    end
    #puts "#{@tags}\n"
    #puts @tags.length
  end
  def find_feature_files(folder)
    feature_files = []
    feature_files << Dir.glob("#{folder}*.feature")
    Dir.glob("#{File.join(folder,'*','')}").each do |sub_folder|
      find_feature_files(sub_folder)
    end
    feature_files.flatten!
  end
  def scan_features_for_tags(feature)
    tag_lines = get_feature_tag_lines(feature)
    get_tags_from_lines(tag_lines)
  end
  def get_feature_tag_lines(feature)
    tag_lines = []
    #Grab all Tag Lines
    File.open(feature, 'r') do |f|
      f.each_line do |line|
        line.strip!
        next if line.start_with?('#')
        if line.start_with?('@')
          if !!@tags_to_skip ##Skipping unwanted tags
            move_on = false
            @tags_to_skip.each do |bad_tag|
              if line.include? bad_tag
                move_on = true
                break
              end
            end
            next if move_on
          end
        end
        tag_lines << line
      end
    end
    tag_lines
  end
  def get_tags_from_lines(tag_lines)
    important = []
    tag_lines.each do |line|
      line.split(' ').each do |tag|
        @tag_prefixes_to_run.each do |prefix|
          important << tag if tag.include? prefix
        end
      end
    end
    #print "#{important}\n"
    important
  end

  #Running and logging
  def run_tags
    total = @tags.length
    puts "Running #{total} test case#{total == 1 ? '' : 's'}"
    @pass,@fail = [],[]
    @tags.each.with_index do |tag,index|
      puts "Executing #{tag} (#{index+1} of #{total})"
      log = launch_cucumber(tag)
      result = cucumber_passed?(log)
      if result #True if passed
        @pass << tag
      else
        @fail << tag
        log_failure(tag,log)
      end
      string = "-- #{result ? color('g','Passed') : color('r','Failed')} at #{time}"
      string += " (#{@pass.length} passed, #{@fail.length} failed)\n"
      puts string
      update_summary
    end
    puts "Done! Totals:#{@pass.length} passed, #{@fail.length} failed.\n\n"
    puts @fail_heatmap
  end
  def launch_cucumber(tag)
    run = `cucumber -c -t #{tag}`
    run
  end
  def cucumber_passed?(string)
    fail_words = ['Failing Scenarios','GemNotFound']
    fail_words.each{|v| return false if string.include?(v)}
    true
  end
  def log_failure(tag,log)
  # @failure_log
    parsed = parse_failure(tag,log)
    save = update_failure_heatmap(parsed)
    save += add_fail_description(parsed)

    File.open(@failure_log_path, 'w') {|f| f.write(save) }
  end
  def parse_failure(tag,log)
    failure_array = []
    log = log.split(tag) #Catches multipule scenarios with one tag
    if has_red_lines?(log[0])
      failure_array << fail_to_hash(log.join(tag),tag)
    else
      log.each.with_index do |scenario,index|
        next if index == 0 #Skip First
        failure_array << fail_to_hash(scenario,tag) if has_red_lines?(scenario)
      end
    end
    failure_array
  end
  def has_red_lines?(str)
    #Note bash printouts have color they start with a [#m and end with [0m (31:red, 90:gray)
    str.include?('[31m')
  end
  def fail_to_hash(str,tag)
    str = extact_red_line(str)
    return nil if str == ''
    str = remove_bash_colors(str)
    red_lines_to_hash(str,tag)
  end
  def extact_red_line(str)
    red_lines = ''
    str.each_line do |line|
      red_lines += line if line[0,6].include?('[31m') #Starts with red
    end
    red_lines
  end
  def red_lines_to_hash(str,tag)
    str = str.split('Failing Scenarios:')
    failure = Hash.new
    failure['scenario'] = str[1].split('common ')[1]
    failure['error'] = str[0].split('\n')[-1]
    failure['step'] = extract_step(failure['error'])
    failure['tag'] = tag
    failure
  end

  def remove_bash_colors(string)
    remove_characters(string,['[0m','[1m','[90m','[36m','[32m','[31m',"\e"])
  end
  def remove_characters(string,character_array)
    character_array.each {|char| string = string.gsub(char,'')}
    string
  end
  def update_failure_heatmap(array_of_hashes)
    @failure_heatmap_hash ||= Hash.new
    array_of_hashes.each do |hash|
      step = hash['step']
      if @failure_heatmap_hash[step].nil?
        @failure_heatmap_hash[step] = 1
      else
        @failure_heatmap_hash[step] = @failure_heatmap_hash[step] + 1
      end
    end

    #Get the longest string for making the print out pretty
    longest_string = 0
    @failure_heatmap_hash.each do |k,_|
      longest_string = k.length if k.length > longest_string
    end

    line = "#{'-'*(longest_string + 12)}\n"
    @fail_heatmap = "Failure Heat Map:\n#{line}"
    @fail_heatmap += "| #{'Count'.ljust(5)} | #{'Step'.ljust(longest_string)} |\n"
    @failure_heatmap_hash.sort_by {|k,v| v}.reverse.each do |k,v|
      @fail_heatmap += "| #{v.to_s.rjust(5)} | #{k.to_s.ljust(longest_string)} |\n"
    end
    @fail_heatmap += line
    @fail_heatmap
  end
  def extract_step(str)
    if @generic_heatmap
      return str.split('/^')[1].split('$/')[0]
    else
      str = str.split("\n")[-1].split('in `')[1].strip
      if str.start_with?('*')
        str = str[2,str.length+1]
      elsif str.start_with?('Given')
        str = str[6,str.length+1]
      elsif (str.start_with?('When') || str.start_with?('Then'))
        str = str[5,str.length+1]
      elsif (str.start_with?('And') || str.start_with?('But'))
        str = str[4,str.length+1]
      end
      return  "'#{str}"
      #TODO Currently return 'step' will remove '' if I can figure out how to remove it at the end and not ones in the middle.
    end
  end
  def add_fail_description(array_of_hashes)
    @fail_tail ||= "\n\nFailure Logs:\n"
    array_of_hashes.each do |hash|
      @fail_tail += "Code ran: bundle exec cucumber -t #{hash['tag']}\n"
      @fail_tail += "Failure location: #{hash['scenario']}"
      @fail_tail += "#{hash['error']}\n\n"
    end
    @fail_tail
  end
  def update_summary
    @start_time ||= Time.now
    @old_summary ||= ''

    string = @old_summary
    string += "\n\nStarted at #{@start_time}\n"
    string += "Scheduled: #{@tags}\n"
    string += "Passed: #{@pass}\n"
    string += "Failed: #{@fail}\n"

    File.open(@summary_log_path, 'w') {|f| f.write(string) }
  end

  #Generic Helpers
  def time
    Time.now.to_s[0...-6].gsub(' ','_')
  end
  def combine_arrays(array_a,array_b)
    array_a << array_b
    array_a.flatten!
    array_a.uniq!
  end
  def question_yes_no
    @question_repeat.times do
      responce = STDIN.gets.chomp.strip.downcase
      boolean = responce == 'y' || responce == 'n' || responce == 'yes' || responce == 'no'
      if boolean
        return true if responce[0,1] == 'y'
        return false
      end
      print "Please respond with (y)es or (n)o: "
    end
    print "\n";abort
  end
  def question_not_blank
    @question_repeat.times do
      responce =  STDIN.gets.chomp.strip
      return responce if responce != ''
      print 'Please type something: '
    end
    print "\n";abort
  end
  def question_separated_by_commas
    split_and_strip(question_not_blank,',')
  end
  def split_and_strip(string,deliminer)
    complete = []
    string.split(deliminer).each {|item| complete << item.strip}
    complete
  end
  def color(color,string)
    case color
    when 'r','red'; return "\e[31m#{string}\e[0m"
    when 'g','green'; return "\e[32m#{string}\e[0m"
    when 'y','yellow'; return "\e[33m#{string}\e[0m"
    when 'b','blue'; return "\e[34m#{string}\e[0m"
    else; return string
    end
  end

end

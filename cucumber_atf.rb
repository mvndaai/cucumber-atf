# -------------------------------------------------------------
# Cucumber Automation Test Framework
# Created by Jason Mavandi
# mvndaai@gmail.com
# Updated Mar 6, 2013
# Verion 0.2.0 
# -------------------------------------------------------------

# -------------------------------------------------------------
# Notes
# - I use tag prefixes so I can run individual scenarios that have numbered tags
# ex. @test.01, @test.02 will both be caught by @test
# -------------------------------------------------------------

## Fill in to skip questions
@project_directory #string
@log_folder_name #string
@tag_prefixes_to_run #array
@tags_to_skip #array

END {
  setup
  collect_tags_from_directory
  run_tags
}

# Setup 
def setup
  @os_windows = (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
  @os_mac = (/darwin/ =~ RUBY_PLATFORM) != nil
  @os_linux = !@os_windows && !@os_mac
  
  #Ask questions if necessary
  ask_project_directory if @project_directory.nil?
  #verify_project_directory
  ask_log_folder_name if @log_folder_name.nil?
  ask_tag_questions if @tag_prefixes_to_run.nil?
  
  #Create log folder/files
  create_log_folder
  name_log_files
end
def ask_project_directory
  print "What is the directory of your cucumber project: "
  @project_directory = question_not_blank
  #puts @project_directory
end
def verify_project_directory
  loop do
    dir = @project_directory
    @project_directory = dir.gsub('~/',"/Users/#{`whoami`.chomp}/") if dir.start_with?('~/')  if @os_mac
    @project_directory = dir.gsub('~/',"/home/#{`whoami`.chomp}/") if dir.start_with?('~/')  if @os_linux 
    break if File.directory?(@project_directory)
    puts "The cucumber directory listed below does not exists, please try again"
    puts "  '#{@project_directory}'"
    ask_project_directory
  end
end
def ask_log_folder_name
  print "Name a log folder(default 'log'): "
  @log_folder_name = STDIN.gets.chomp.strip
  @log_folder_name = 'log' if @log_folder_name == ''
  #puts @log_folder_name
end
def ask_tag_questions
  print "List important starts of tags, separated by commas (Starting with @): "
  @tag_prefixes_to_run = question_separated_by_commas
  print "#{@tag_prefixes_to_run}\n"
  if @tags_to_skip.nil?
    print "Are there any tags you would like to skip?(y/n): "
    if question_yes_no
      print 'List tags to skip separated by commas: '
      @tags_to_skip = question_separated_by_commas
      print "#{@tags_to_skip}\n"
    end
  end
end
def create_log_folder
  @log_directory = File.join(@project_directory,@log_folder_name)
  return if File.directory?(@log_directory)
  Dir::mkdir(@log_directory)
  #puts @log_directory
end
def name_log_files
  summary = "atf-summary.txt"
  failure = "atf-fail-#{time}.txt"
  @summary_log_name = File.join(@log_directory,summary)
  @failure_log_name = File.join(@log_directory,failure)
  #File.open(@summary_log, 'w') {|f| f.write("Start at #{Time.now}") }
end

#Gather tags from feature files
def collect_tags_from_directory
  return if @tags.any? if !!@tags #Hack to let you force tags instead of searching
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
  Dir.glob("#{File.join(folder,'*','')}").each do |sub_folder|
    feature_files << Dir.glob("#{sub_folder}*.feature")
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
  #puts "\n\n#{tag_lines}"
  tag_lines.each do |line|
    #puts line
    line.split(' ').each do |tag|
      @tag_prefixes_to_run.each do |prefix|
        #puts "#{prefix} - #{tag}"
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
  pass,fail = [],[]
  @tags.each.with_index do |tag,index|
    puts "Executing #{tag} (#{index+1} of #{total})"
    log = launch_cucumber(tag)
    result = cucumber_passed?(log)
    if result #True if passed
      pass << tag
    else
      fail << tag
      log_failure(tag,log)      
    end
    string = "-- #{result ? "\e[32mPassed\e[0m" : "\e[31mFailed\e[0m"} at #{time}"
    string += " (#{pass.length} passed, #{fail.length} failed)\n" 
    puts string
    update_summary(tag) 
  end
  puts "Done! Totals:#{pass.length} passed, #{fail.length} failed.\n\n"
  puts @fail_heatmap
end
def launch_cucumber(tag)
  `cd #{@project_directory}; bundle exec cucumber -t #{tag}` 
end  
def cucumber_passed?(string)
  (string.include? 'Failing Scenarios') ? false : true
end
def log_failure(tag,log)
# @failure_log
  parsed = parse_failure(tag,log)
  save = update_failure_heatmap(parsed)
  save += add_fail_description(parsed)
  
  #Catch multipule scenario failures
  #-Split log by @ begining of stripped line
  
  File.open(@failure_log_name, 'w') {|f| f.write(save) } 
end
def parse_failure(tag,log)
  #Note bash printouts have color they start with a [#m and end with [0m
  # [31m is red, [90m is gray
  
  failure_array = []
  log = log.split(tag) #Catches multipule scenarios with one tag
  log.each.with_index do |scenario,index|
    next if index == 0 #Skip First
    red_lines = '' 
    scenario.each_line do |line|
      line = line.lstrip.gsub('\e','')
      red_lines += line if line[0,6].include?("[31m") #Starts with red
    end
    next if red_lines == ''
    
    red_lines = remove_bash_colors(red_lines).split('Failing Scenarios:')
    failure = Hash.new
    failure['scenario'] = red_lines[1].split('common ')[1]
    failure['step'] = red_lines[0].split('\n')[-1]
    failure['tag'] = tag    
        
    failure_array << failure
  end
  #puts failure_array
  failure_array
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
    step = hash['step'].split("\n")[-1].split('in `')[1].strip
    #TODO figure out how to remove the ' at the end
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
  #puts string
  @fail_heatmap
end
def add_fail_description(array_of_hashes)
  @fail_tail ||= "\n\nFailure Logs:\n"
  array_of_hashes.each do |hash|
    @fail_tail += "Code ran: bundle exec cucumber -t #{hash['tag']}\n"
    @fail_tail += "Failure location: #{hash['scenario']}"
    @fail_tail += "#{hash['step']}\n\n"
  end
  @fail_tail
end

def update_summary(tag)
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
  loop do
    responce = STDIN.gets.chomp.strip.downcase
    boolean = responce == 'y' || responce == 'n' || responce == 'yes' || responce == 'no'
    if boolean
      return true if responce[0,1] == 'y'
      return false
    end
    print "Please respond with (y)es or (n)o: "
  end
end
def question_not_blank
  loop do
    responce =  STDIN.gets.chomp.strip
    return responce if responce != ''
    print 'Please type something: '
  end
end
def question_separated_by_commas
  split_and_strip(question_not_blank,',')
end
def split_and_strip(string,deliminer)
  complete = []
  string.split(deliminer).each {|item| complete << item.strip}
  complete
end
def test_file(string)
   File.open(File.join(@log_directory,'test.txt'), 'w') {|f| f.write(string) } 
end

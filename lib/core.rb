#!/usr/math/bin/ruby


require 'yaml'
require 'find'

module RnsGit
  class Core

    BIN = 'rnsgit'

    HELP = <<ENDHELP
    #{BIN} version #{RnsGit::VERSION }
  ----------------------------------
  Usage: #{BIN} command [command options ] [song-file.xrns]
  If you omit the name of the xrns file you need to have a .rnsgit file with the song name.

  An example series of commands:

      $ #{BIN} init my-colossal-song.xrns                         # Creates a repo name my-colossal-song
      $ #{BIN} co "Added superbad vocals"  my-colossal-song.xrns  # Updates repo and commits the changes
      $ #{BIN} pin                                                # Creates or updates the local .#{BIN} file

  With the .#{BIN} file in place you can omit passing the name of the song file

      $ #{BIN} br "faster-version"   # Creates a new branch, named, "faster-version" , in the my-colossal-song repo
      $ #{BIN} st   #  Show the status of the my-colossal-song repo

ENDHELP

    def usage
      puts HELP
    end


    def win32?
      RUBY_PLATFORM =~ /ming32/ ? true : false
    end


    def help? argv
      case argv.first
      when 'help', '-h', '--help'
        true
      else
        false
      end
    end

    def initialize argv

      if argv.empty? || help?(argv)
        usage
        exit
      end

      if argv.last =~ /.xrns/
        @xrns = argv.pop
      else
        if File.exist?  dot_file 
          @dot_config = YAML.load_file dot_file 
          @xrns = @dot_config[:xrns]
        else
          warn "You need to pass either an xrns file or there needs to be a valid #{dot_file} file"
          exit
        end
      end

      process argv

    end

    def dot_config
      @dot_config ||= {}
    end

    def dot_file 
   '.rnsgit'
    end


    # The idea is to allow the use of a .rnsgit file that defines
    # some default values so that the user can avoid having to
    # pass in the song name for every operation
    #

    def process argv

      puts "\t\t******** #{xrns} ********"
      command = argv.shift

      case command
      when 'help', '-h', '--help'
        usage

      when 'init'
        msg = argv.shift || "New repo"
        unzip_to_git msg

      when 'set', 'pin'
        pin_current_song

      when 'build', 'make', 'zip', 'xrns'
        zip_to_xrns 

      when 'unzip', 'extract'
        msg = argv.shift || "Unzipped current xrns"
        unzip_to_git 


      when 'st', 'status'
        status_repo 

      when 'br', 'branch'

        if branch_name = argv.shift
          if branch_name  =~ /^-/
            puts git_proxy 'br', branch_name 
          else
            branch_repo branch_name 
          end
        else
          puts git_proxy 'br'   
        end

      when 'co', 'checkout'
        branch_name = argv.shift
        name_modifier = argv.shift
        xrns_from_branch branch_name, name_modifier

      when 'ci', 'commit'  # Note: Look at unzip_to_git  to see what actual git call is used.
        # It is probably doing `ci -am`
        unzip_to_git argv.shift

      when 'branches' # This is just a nicety
        warn "List all branches ..."
        puts list_branches 

      when 'nice-merge'
        # The idea is to not interfere too much with default git behavior; let people merge as they care to.
        # nice-merge is an attempt to make to process a little easier since the wrapper code
        # interferes with autocomplete; you would need to know and  type the full branch name
        # you are merging.
        # So, hopefully, nice-merge can prompt the user and read the input 
        # and make it easier to select what branch to merge with the current branch.
        nice_merge 
      else
        #  The goal is to have the script respond to specialized
        #  commands (such as 'set') while assuming that if
        #  the user passes something not specified here then it
        #  is a git command.
        #  
        #  The assumption is that the song name (and therefor the repo)
        #  has been determined and that if the last arg was
        #  a song file name then that has already been removed from argv
        #  
        #  Therefore all that remains in arg should be a git command and
        #  any args that command might use
        #  
        #  But note: Some git commands, such as changing branches or committing changed files
        #  need to work with the xrns file.  Those commands need to be intercepted
        #  so that this script can do the extra magic
        #  This can be tricky; one would have to go through every possible git command
        #  to see if there is usage such that it would need to either unzip the xnrs in order
        #  to update the repo files or rezip the xrns with any altered repo files.
        #
        #  At the moment this is not being attempted.  The immediate goal is "good enough"
        #  command coverage such that a user can update the repo from an xrns, 
        #  and update an xrns from the repo for the more common things like br or co
        #
        #  At the very least a user can always use the `zip` and `unzip` commands to
        #  make or extract the xrns, and can cd into the actual repo and so as they
        #  like using git directly.
        puts git_proxy command, *argv 
      end
    end

    def xrns 
      @xrns 
    end

    def repo
      @repo ||= @xrns.sub '.xrns', ''
    end

    def pin_current_song
      File.open(dot_file, 'w') {|f|
        f.puts %~:xrns: "#{xrns}"~
      }
    end

    def check_song_xml_for text_re
      found = false
      IO.readlines("#{repo}/Song.xml").each do |l|
        l.strip!
        if l =~ text_re
          found = true
        end
      end
      found

    end

    def unzip_to_existing_repo
    unless src_folder_exists? 
        raise "Cannot unzip to an existing repo because '#{repo}' does not exist."
      end
      warn `cp #{xrns} #{repo}`

      Dir.chdir repo do
        warn "In #{repo} calling 7z -y x #{xrns}"
        warn `7z -y x #{xrns}`
        warn `rm #{xrns}`
      end
    end

    # Assume we have a song in the folder 'songs'
    # We want to copy it out form there and then see if we can extract it into
    # a folder named after the song

    # Do we want to assume there are installed tools, like 7z?
    # Yes, if it makes stuff move forward.

    def unzip_to_git msg
      unless src_folder_exists? 
        `mkdir #{repo}`
      end

      warn `cp #{xrns} #{repo}`

      Dir.chdir repo do
        warn "In #{repo} calling 7z -y x #{xrns}"
        warn `7z -y x #{xrns}`
        warn `rm #{xrns}`

        unless File.exist? '.git'
          warn "We have no git stuff here."
          warn "git init"
          warn `git init`
          warn 'git add *'
          warn `git add *`
          warn 'git commit -am "New"'
          warn `git commit -am "New"`
        else

          warn "This folder is already under git!"
          warn `git status`
          warn `git add */** `  # Is this right? 
          # FIXME Need to escape double-quotes in any strings to be added to te git command, such as in a commit message.
          # FIXME Need to escape single-quotes in any strings to be added to te git command, such as in a commit message.
          # Windows seems to dick you over if you use single-quotes in CMD.exe. 
          warn `git commit -am "#{msg}"`
        end

      end
    end

    def check_out_branch branch_name
      unless is_git_repo? 
        warn "No existing git repo in folder '#{repo}'"
        # raise "No existing git repo in folder '#{repo}'"  # TODO Give more thought to when and where to raise errors
        return nil
      end

      # TODO : See if git on different platforms or different versions adds quotes to branch names in messages
      _ = git_proxy "checkout #{branch_name}" 
      switched_re = Regexp.new "Switched to branch '#{branch_name}'"
      existing_re = /already exists|already on/i
      _.strip!

      return true if switched_re =~ _  
      return true if existing_re =~ _

      # TODO Give more thought to when and where to raise errors
      raise "Failed to checkout branch #{branch_name}:#{_}"
    end

    def branch_repo branch_name
      unless File.exist? repo
        warn "No existing repo folder '#{repo}'"
        raise "No existing repo folder '#{repo}'"  # TODO Give more thought to when and where to raise errors
        return
      end

      Dir.chdir repo do
        unless File.exist? '.git'
          warn "No existing git repo in folder '#{repo}'"
          raise "No existing git repo in folder '#{repo}'"  # TODO Give more thought to when and where to raise errors
          return
        end

        # Do we need to see if there are uncommited changes?
        warn `git branch #{branch_name}`
      end

      check_out_branch branch_name

    end

    def status_repo 
      # The repo has the extracted song files.
      # If you are edting a song, the changes are saved into the xrns file; the repo
      # knows nothing of these.
      # In normal git usage when you edit a fle and save it the repo sees this.
      # So, when a user asks about the repo status the code will unzip the song into the repo first.
      unzip_to_existing_repo  
      puts git_proxy "status"
    end

    def git_proxy git_cmd, *args

      unless is_git_repo? 
        warn "No existing git repo in folder '#{repo}'"
        return nil
      end

      _ = ''
      Dir.chdir repo do
        # Do we need to see if there are uncommited changes?
        _ = `git #{git_cmd} #{args.join ' '} 2>&1`
      end
      _
    end

    def list_branches 
      git_proxy 'branch --all'
    end

    def src_folder_exists? 
      File.exist? repo
    end

    def is_git_repo? 
      unless src_folder_exists? 
        warn "No existing folder '#{repo}'"
        return nil
      end

      File.exists? "#{repo}/.git"
    end


    def xrns_from_branch branch_name, name_modifier = nil
      if is_git_repo? 
        if check_out_branch branch_name
          # This is an assumption, that the song file is dereived from the repo name, and viceversa.
          xrns = repo + name_modifier.to_s + '.xrns'
          warn "***** Create #{xrns} ******"
          zip_to_xrns 
        else
          # TODO Give more thought to when and where to raise errors
          raise "xrns_from_branch failed to chechout '#{branch_name}'"
        end
      else
        warn "'#{repo}' is not a git repo!"
        raise "'#{repo}' is not a git repo!" # TODO Give more thought to when and where to raise errors
      end
    end

    def stash_name xrns
      "._stashed_#{xrns}"
    end

    def remove_stash_xrns xrns
      _ = stash_name xrns
      if File.exist? _
        puts `rm #{_} `
      end
    end

    def current_branch
      _ = git_proxy 'branch' 
      __ = _.split "\n"

      # God this looks hacky!  FIXME or something.
      _  = __.select{|b| b.strip =~ /^\*/ }.first.sub /^\*/ ,''
      # Need to clean this up?
      _
    end

    def available_merge_branches
      git_proxy('branch').split("\n").select{ |b| b.strip !~ /^\*/ } 
    end

    def nice_merge 
      warn "Nice merge!"
      # The steps:
      # Tell the user the current branch, and list the available branches, number
      puts "Current branch: #{current_branch}"
      # Prompt the user to enter the numnber of the branch to merge, or q/Q to quit

      puts "Availbe merge branches:"
      available_merge_branches.each_with_index do |b,i|
        puts "\t#{i+1}:\t#{b}"  
      end
      puts "Enter the number of the branch to merge, or c to cancel."
      bi = gets
      if bi.to_i > 0
        # Assume this is a branch selection number
        if branch = available_merge_branches[bi.to_i-1]
          puts "Merging '#{current_branch}' with '#{branch.strip}' ..."
          puts git_proxy "merge #{branch.strip}"
          zip_to_xrns  
        else
          puts "That is not  a valid selection."
        end
      else
        # We don't really care what the user entered; if not a number then we just quit
        puts "Canceled"
      end
    end

    def stash_xrns xrns
      if File.exist? xrns
        puts `mv #{xrns} #{stash_name xrns}`
      end
    end


    # See if the xrns file is newer than the newest file in the repo
    def song_is_newer_than_the_repo?
      song_ts = File.mtime xrns
      newest_repo_ts = 0 
      File.chdir repo do |rf|
        p rf

      end

    end



    # FIXME
    # On Windows there is a chance the repo will have folder and file names that exceed some goofy win32 limitation
    # it may be possible to avoid this: http://sourceforge.net/p/sevenzip/discussion/45797/thread/67334954/
    #
    # It seems to require prefixing every file path with something or other.
    #
    # Need to determine if the issue is wth extracting to long names and/or zipping up long names
    #
    #
    def zip_to_xrns 

      if src_folder_exists? 
        stash_xrns xrns
        puts "Zipping up repo files into #{xrns} ..."

      
        files = []

        Dir.chdir repo do 
          # What if we add each file on its own?    
          #          puts `7z -tzip a #{xrns} -xr!.git -r . `

          _pwd = Dir.pwd + '/'
          Find.find(Dir.pwd) { |path|
            puts  "path to zip '#{path}'" # DEBUG
      
            if FileTest.directory? path
              if File.basename(path)[0] == ?.
                Find.prune      
              else
                next
              end
            else
             unless File.basename(path)[0] == ?.
              files << path
             end
            end
          } 

           warn "files to zip: #{files.inspect}"  # DEBUG
           files.each do |f|
            f.sub! _pwd, ''
             puts %~7z -tzip a #{xrns} "#{f}"~
             puts `7z -tzip a #{xrns} "#{f}"`
           end

          unless File.exist? xrns
            raise "Failed to create #{xrns}"
          else
            puts "We have the xrns #{xrns}"
          end

      
        end
        warn "Move #{repo}/#{xrns} to here ..."
        puts `mv #{repo}/#{xrns} .`  # mv is not going to work onm Windows machines unless users have unix utils    FIXME
        remove_stash_xrns xrns
        

      else
        warn "No folder '#{repo}'"
        raise "No folder '#{repo}'"  # TODO Give more thought to when and where to raise errors
      end
    end

  end
end



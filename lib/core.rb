#!/usr/math/bin/ruby


require 'yaml'

module RnsGit
  class Core

    BIN = 'rnsgit'

    HELP = <<ENDHELP

  #{BIN} command [command options ] [song-file.xrns]
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
        warn `7z -y x #{xrns}`
        warn `rm #{xrns}`

        unless File.exist? '.git'
          warn "We have not git stuff here"
          warn `git init ; git add *; git ci -am "New"`
        else
          warn "This folder is already under git!"
          warn `git st`
          warn ` git ci -am #{msg}`
        end

      end
    end

    def check_out_branch branch_name
      unless is_git_repo? 
        warn "No existing git repo in folder '#{repo}'"
        # raise "No existing git repo in folder '#{repo}'"  # TODO Give more thought to when and where to raise errors
        return nil
      end

      _ = git_proxy "checkout '#{branch_name}'" 
      re = Regexp.new "Switched to branch '#{branch_name}'"
      existing_re = /already exists|already on/i
      _.strip!

      return true if re =~ _  
      return true if existing_re =~ _

      # TODO Give more thought to when and where to raise errors
      raise "Failed to checkout branch '#{branch_name}':#{_}"
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
        warn `git br '#{branch_name}'`
      end

      check_out_branch branch_name

    end

    def status_repo 
      git_proxy "status"
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
      git_proxy 'branch -all'
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

    def stash_xrns xrns
      if File.exist? xrns
        puts `mv #{xrns} #{stash_name xrns}`
      end
    end

    def zip_to_xrns 
      if src_folder_exists? 
        stash_xrns xrns
        Dir.chdir repo do 
          puts `7z -tzip a #{xrns} -xr!.git -r . `
        end

        puts `mv #{repo}/#{xrns} .`
        remove_stash_xrns xrns

      else
        warn "No folder '#{repo}'"
        raise "No folder '#{repo}'"  # TODO Give more thought to when and where to raise errors
      end

    end
  end
end



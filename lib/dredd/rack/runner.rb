module Dredd
  module Rack

    # A Ruby wrapper around the Dredd API blueprint validation tool
    #
    # Usage:
    #
    #    # run `dredd doc/*.apib doc/*.apib.md http://localhost:3000 --level warning --dry-run`
    #    dredd = Dredd::Rack::Runner.new
    #    dredd.level(:warning).dry_run!.run
    #
    #    anderson = Anderson::Rack::Runner.new 'https://api.example.com' do |options|
    #      options.paths_to_blueprints 'blueprints/*.md', 'doc/*.md'
    #      options.no_color!
    #    end
    #    anderson.run # runs `dredd blueprints/*.md doc/*.md https://api.example.com --no-color`
    #
    class Runner

      undef_method :method

      NEGATABLE_BOOLEAN_OPTIONS = [:dry_run!, :names!, :sorted!, :inline_errors!,
                                   :details!, :color!, :timestamp!, :silent!]
      META_OPTIONS              = [:help, :version]
      BOOLEAN_OPTIONS           = NEGATABLE_BOOLEAN_OPTIONS + META_OPTIONS

      SINGLE_ARGUMENT_OPTIONS   = [:hookfiles, :only, :reporter, :output, :header,
                                   :user, :method, :level, :path]
      OPTIONS                   = BOOLEAN_OPTIONS + SINGLE_ARGUMENT_OPTIONS

      # Store the Dredd command line options
      attr_accessor :command_parts

      # Initialize a runner instance
      #
      # The API endpoint can be local or remote.
      #
      # api_endpoint - the API URL as a String
      #
      def initialize(api_endpoint=nil)
        raise ArgumentError, 'invalid API endpoint' if api_endpoint == ''

        @dredd_command = 'dredd'
        @paths_to_blueprints = 'doc/*.apib doc/*.apib.md'
        @api_endpoint = api_endpoint || 'http://localhost:3000'
        @command_parts = []

        yield self if block_given?
      end

      # Return the Dredd command line
      def command
        ([@dredd_command, @paths_to_blueprints, @api_endpoint] + @command_parts).join(' ')
      end

      # Define custom paths to blueprints
      #
      # paths_to_blueprints - as many Strings as paths where blueprints are located
      #
      # Returns self.
      def paths_to_blueprints(*paths_to_blueprints)
        raise ArgumentError, 'invalid path to blueprints' if paths_to_blueprints == ['']

        @paths_to_blueprints = paths_to_blueprints.join(' ')
        self
      end

      # Run Dredd
      #
      # Returns true if the Dredd exit status is zero, false instead.
      def run
        Kernel.system(command) if command_valid?
      end

      # Ensure that the runner does respond_to? its option methods
      #
      # See http://ruby-doc.org/core-2.2.0/Object.html#method-i-respond_to_missing-3F
      def respond_to_missing?(method, include_private=false)
        OPTIONS.include?(method.to_sym ) ||
        NEGATABLE_BOOLEAN_OPTIONS.include?(method.to_s.gsub(/\Ano_/, '').to_sym) ||
        super
      end

      private

        def command_valid?
          command.has_at_least_two_arguments?
        end

        # Private: Define as many setter methods as there are Dredd options
        #
        # The behaviour of Object#method_missing is not modified unless
        # the called method name matches one of the Dredd options.
        #
        # name - Symbol for the method called
        # args - arguments of the called method
        #
        # See also: http://ruby-doc.org/core-2.2.0/BasicObject.html#method-i-method_missing
        def method_missing(name, *args)
          super unless OPTIONS.include?(name.to_sym ) ||
                       NEGATABLE_BOOLEAN_OPTIONS.include?(name.to_s.gsub(/\Ano_/, '').to_sym)

          option_flag = name.to_s.gsub('_', '-').gsub('!', '').prepend('--')
          command_parts = self.command_parts.push option_flag
          command_parts = self.command_parts.push args.slice(0).to_s if SINGLE_ARGUMENT_OPTIONS.include? name
          self
        end

    end
  end
end

class String

  # Verify that a command has at least two arguments (excluding options)
  #
  # Examples:
  #
  #    "dredd doc/*.apib http://api.example.com".valid? # => true
  #    "dredd doc/*.apib doc/*apib.md http://api.example.com".valid? # => true
  #    "dredd doc/*.apib http://api.example.com --level verbose".valid? # => true
  #    "dredd http://api.example.com".valid? # => false
  #    "dredd doc/*.apib --dry-run".valid? # => false
  #    "dredd --dry-run --level verbose".valid? # => false
  #
  # Known limitations:
  #
  # Does not support short flags. (e.g. using `-l` instead of `--level`).
  # Requires options to be specified after the last argument.
  #
  # Note:
  #
  # The known limitations imply that there may be false negatives: this method
  # can return false for commands that do have two arguments or more. But there
  # should not be false positives: if the method returns true, then the command
  # does have at least two arguments.
  #
  # Returns true if the command String has at least two arguments, false otherwise.
  def has_at_least_two_arguments?
    split('--').first.split(' ').length >= 3
  end
end

Anderson = Dredd # Anderson::Rack::Runner.new runs just as fast as Dredd

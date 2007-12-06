module Nanoc
  class Site

    DEFAULT_CONFIG = {
      :output_dir   => 'output',
      :eruby_engine => 'erb',
      :data_source  => 'filesystem'
    }

    attr_reader :config
    attr_reader :compiler, :data_source
    attr_reader :code, :pages, :page_defaults, :layouts, :templates

    # Creating a Site object

    def self.from_cwd
      if File.directory?('tasks') and File.file?('config.yaml') and File.file?('Rakefile')
        new
      else
        nil
      end
    end

    def initialize
      # Load configuration
      @config = DEFAULT_CONFIG.merge(YAML.load_file_and_clean('config.yaml'))

      # Create data source
      @data_source_class = PluginManager.data_source_named(@config[:data_source])
      error "Unrecognised data source: #{@config[:data_source]}" if @data_source_class.nil?
      @data_source = @data_source_class.new(self)

      # Create compiler
      @compiler = Compiler.new(self)

      # Set not loaded
      @data_loaded = false
    end

    def load_data(params={})
      return if @data_loaded and params[:force] != true

      # Start data source
      @data_source.up

      # Load data
      @code           = @data_source.code
      @pages          = @data_source.pages.map { |p| Page.new(p, self) }
      @page_defaults  = @data_source.page_defaults
      @layouts        = @data_source.layouts
      @templates      = @data_source.templates

      # Stop data source
      @data_source.down

      # Setup child-parent links
      @pages.each do |page|
        # Skip pages without parent
        next if page.path == '/'

        # Get parent
        parent_path = page.path.sub(/[^\/]+\/$/, '')
        parent = @pages.find { |p| p.path == parent_path }

        # Link
        page.parent = parent
        parent.children << page
      end

      # Set loaded
      @data_loaded = true
    end

    # Compiling

    def compile
      load_data
      @compiler.run
    end

    def autocompile
      load_data
      @autocompiler ||= @data_source.autocompiler_class.nil? ? nil : @data_source.autocompiler_class.new(self)
      if @autocompiler.nil?
        error 'ugh'
      else
        @autocompiler.start
      end
    end

    # Creating

    def setup
      @data_source.up
      @data_source.setup
      @data_source.down
    end

    def create_page(name, template_name='default')
      load_data

      template = @templates.find { |t| t[:name] == template_name }

      @data_source.up
      @data_source.create_page(name, template)
      @data_source.down
    end

    def create_template(name)
      load_data

      @data_source.up
      @data_source.create_template(name)
      @data_source.down
    end

    def create_layout(name)
      load_data

      @data_source.up
      @data_source.create_layout(name)
      @data_source.down
    end

  end
end

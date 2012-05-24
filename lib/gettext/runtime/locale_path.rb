# encoding: utf-8

=begin
  locale_path.rb - GetText::LocalePath

  Copyright (C) 2001-2010  Masao Mutoh

  You may redistribute it and/or modify it under the same
  license terms as Ruby or LGPL.

=end

require 'rbconfig'
require 'gettext/core_ext/string'

module GetText
  # Treats locale-path for mo-files.
  class LocalePath
    include Locale::Util::Memoizable

    # The default locale paths.
    CONFIG_PREFIX = Config::CONFIG['prefix'].gsub(/\/local/, "")
    DEFAULT_RULES = [
                     "./locale/%{lang}/LC_MESSAGES/%{name}.mo",
                     "./locale/%{lang}/%{name}.mo",
                     "#{Config::CONFIG['datadir']}/locale/%{lang}/LC_MESSAGES/%{name}.mo",
                     "#{Config::CONFIG['datadir'].gsub(/\/local/, "")}/locale/%{lang}/LC_MESSAGES/%{name}.mo",
                     "#{CONFIG_PREFIX}/share/locale/%{lang}/LC_MESSAGES/%{name}.mo",
                     "#{CONFIG_PREFIX}/local/share/locale/%{lang}/LC_MESSAGES/%{name}.mo"
                    ].uniq

    class << self
      include Locale::Util::Memoizable

      # Add default locale path. Usually you should use GetText.add_default_locale_path instead.
      # * path: a new locale path. (e.g.) "/usr/share/locale/%{lang}/LC_MESSAGES/%{name}.mo"
      #   ('locale' => "ja_JP", 'name' => "textdomain")
      # * Returns: the new DEFAULT_LOCALE_PATHS
      def add_default_rule(path)
        DEFAULT_RULES.unshift(path)
      end

      # Returns path rules as an Array.
      # (e.g.) ["/usr/share/locale/%{lang}/LC_MESSAGES/%{name}.mo", ...]
      def default_path_rules
        default_path_rules = []

        if ENV["GETTEXT_PATH"]
          ENV["GETTEXT_PATH"].split(/,/).each {|i|
            default_path_rules += ["#{i}/%{lang}/LC_MESSAGES/%{name}.mo", "#{i}/%{lang}/%{name}.mo"]
          }
        end
        default_path_rules += DEFAULT_RULES

        load_path = $LOAD_PATH.dup
        if defined? ::Gem
          paths_to_latest_gems = []
          latest_specs = Gem::Specification.each do |spec|
            paths_to_latest_gems << spec.gem_dir if spec.activated
          end

          load_path += paths_to_latest_gems
        end
        load_path.map!{|v| v.match(/(.*?)(\/lib)*?$/); $1}
        load_path.each {|path|
          default_path_rules += [
                                 "#{path}/data/locale/%{lang}/LC_MESSAGES/%{name}.mo",
                                 "#{path}/data/locale/%{lang}/%{name}.mo",
                                 "#{path}/locale/%{lang}/%{name}.mo"]
        }
        # paths existed only.
        default_path_rules = default_path_rules.select{|path|
          Dir.glob(path % {:lang => "*", :name => "*"}).size > 0}.uniq
        default_path_rules
      end
      memoize_dup :default_path_rules
    end

    attr_reader :locale_paths, :supported_locales

    # Creates a new GetText::TextDomain.
    # * name: the textdomain name.
    # * topdir: the locale path ("%{topdir}/%{lang}/LC_MESSAGES/%{name}.mo") or nil.
    def initialize(name, topdir = nil)
      @name = name

      if topdir
        path_rules = ["#{topdir}/%{lang}/LC_MESSAGES/%{name}.mo", "#{topdir}/%{lang}/%{name}.mo"]
      else
        path_rules = self.class.default_path_rules
      end

      @locale_paths = {}
      path_rules.each do |rule|
        this_path_rules = rule % {:lang => "([^\/]+)", :name => name}
        Dir.glob(rule %{:lang => "*", :name => name}).each do |path|
          if /#{this_path_rules}/ =~ path
            @locale_paths[$1] = path.untaint unless @locale_paths[$1]
          end
        end
      end
      @supported_locales = @locale_paths.keys.sort
    end

    # Gets the current path.
    # * lang: a Locale::Tag.
    def current_path(lang)
      lang_candidates = lang.to_posix.candidates
      search_files = []

      lang_candidates.each do |tag|
        path = @locale_paths[tag.to_s]
        warn "GetText::TextDomain#load_mo: mo-file is #{path}" if $DEBUG
        return path if path
      end

      if $DEBUG
        warn "MO file is not found in"
        @locale_paths.each do |path|
          warn "  #{path[1]}"
        end
      end
      nil
    end
    memoize :current_path

  end
end

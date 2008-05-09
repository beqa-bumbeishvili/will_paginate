require 'will_paginate/core_ext'

module WillPaginate
  module Finders
    # Database-agnostic finder logic
    module Common
      # Default per-page limit
      def per_page() 30 end
      
      # This is the main paginating finder.
      #
      # == Special parameters for paginating finders
      # * <tt>:page</tt> -- REQUIRED, but defaults to 1 if false or nil
      # * <tt>:per_page</tt> -- defaults to <tt>CurrentModel.per_page</tt> (which is 30 if not overridden)
      # * <tt>:total_entries</tt> -- use only if you manually count total entries
      # * <tt>:count</tt> -- additional options that are passed on to +count+
      # * <tt>:finder</tt> -- name of the ActiveRecord finder used (default: "find")
      #
      # All other options (+conditions+, +order+, ...) are forwarded to +find+
      # and +count+ calls.
      def paginate(*args, &block)
        options = args.pop
        page, per_page, total_entries = wp_parse_options(options)
        finder = (options[:finder] || 'find').to_s

        if finder == 'find'
          # an array of IDs may have been given:
          total_entries ||= (Array === args.first and args.first.size)
          # :all is implicit
          args.unshift(:all) if args.empty?
        end

        WillPaginate::Collection.create(page, per_page, total_entries) do |pager|
          count_options = options.except :page, :per_page, :total_entries, :finder
          find_options = count_options.except(:count).update(:offset => pager.offset, :limit => pager.per_page) 
          
          args << find_options
          pager.replace send(finder, *args, &block)
          
          # magic counting for user convenience:
          pager.total_entries = wp_count(count_options, args, finder) unless pager.total_entries
        end
      end

      # Iterates through all records by loading one page at a time. This is useful
      # for migrations or any other use case where you don't want to load all the
      # records in memory at once.
      #
      # It uses +paginate+ internally; therefore it accepts all of its options.
      # You can specify a starting page with <tt>:page</tt> (default is 1). Default
      # <tt>:order</tt> is <tt>"id"</tt>, override if necessary.
      #
      # {Jamis Buck describes this}[http://weblog.jamisbuck.org/2007/4/6/faking-cursors-in-activerecord]
      # and also uses a more efficient way for MySQL.
      def paginated_each(options = {}, &block)
        options = { :order => 'id', :page => 1 }.merge options
        options[:page] = options[:page].to_i
        options[:total_entries] = 0 # skip the individual count queries
        total = 0
        
        begin 
          collection = paginate(options)
          total += collection.each(&block).size
          options[:page] += 1
        end until collection.size < collection.per_page
        
        total
      end
      
      protected
        
        def wp_parse_options(options) #:nodoc:
          raise ArgumentError, 'parameter hash expected' unless options.respond_to? :symbolize_keys
          options = options.symbolize_keys
          raise ArgumentError, ':page parameter required' unless options.key? :page
          
          if options[:count] and options[:total_entries]
            raise ArgumentError, ':count and :total_entries are mutually exclusive'
          end

          page     = options[:page] || 1
          per_page = options[:per_page] || self.per_page
          total    = options[:total_entries]
          [page, per_page, total]
        end
        
    end
  end
end

require 'minitest/junit/version'
require 'minitest'
require 'socket'
require 'time'

# XML backend: Ox (fastest) > Nokogiri (fast) > REXML (stdlib fallback).
begin
  require 'ox'
  require 'minitest/junit/xml_ox'
rescue LoadError
  begin
    require 'nokogiri'
    require 'minitest/junit/xml_nokogiri'
  rescue LoadError
    require 'rexml/document'
    require 'minitest/junit/xml_rexml'
  end
end

# :nodoc:
module Minitest
  module Junit
    Document = if defined?(Ox)
                 OxDocument
               elsif defined?(Nokogiri)
                 NokogiriDocument
               else
                 RexmlDocument
               end

    # :nodoc:
    class Reporter
      def initialize(io, options)
        @io = io
        @results = []
        @options = options
        @options[:timestamp] = options.fetch(:timestamp, Time.now.iso8601)
        @options[:hostname] = options.fetch(:hostname, Socket.gethostname)
        @doc = Document.new
      end

      def passed?
        true
      end

      def start; end

      def record(result)
        @results << result
      end

      def report
        doc = @doc.document

        testsuites = @doc.element('testsuites')
        @doc.set_attr(testsuites, 'name', @options[:name] || 'minitest')
        @doc.set_attr(testsuites, 'tests', @results.size)
        @doc.set_attr(testsuites, 'skipped', @results.count(&:skipped?))
        @doc.set_attr(testsuites, 'failures', @results.count { |result| !result.error? && result.failure })
        @doc.set_attr(testsuites, 'errors', @results.count(&:error?))
        @doc.set_attr(testsuites, 'time', format_time(@results.map(&:time).inject(0, :+)))

        grouped = @results.group_by { |result| format_file(result) }
        grouped.each do |file, results|
          testsuite = @doc.element('testsuite')
          @doc.set_attr(testsuite, 'name', file)
          @doc.set_attr(testsuite, 'timestamp', @options[:timestamp])
          @doc.set_attr(testsuite, 'hostname', @options[:hostname])
          @doc.set_attr(testsuite, 'tests', results.size)
          @doc.set_attr(testsuite, 'skipped', results.count(&:skipped?))
          @doc.set_attr(testsuite, 'failures', results.count { |result| !result.error? && result.failure })
          @doc.set_attr(testsuite, 'errors', results.count(&:error?))
          @doc.set_attr(testsuite, 'time', format_time(results.map(&:time).inject(0, :+)))
          results.each do |result|
            @doc.add_child(testsuite, format(result))
          end
          @doc.add_child(testsuites, testsuite)
        end

        @doc.add_child(doc, testsuites)
        @io << @doc.dump(doc)
      end

      def format(result, parent = nil)
        testcase = @doc.element('testcase')
        @doc.set_attr(testcase, 'classname', format_class(result))
        @doc.set_attr(testcase, 'name', format_name(result))
        @doc.set_attr(testcase, 'time', format_time(result.time))
        @doc.set_attr(testcase, 'file', relative_to_cwd(result.source_location.first))
        @doc.set_attr(testcase, 'line', result.source_location.last)
        @doc.set_attr(testcase, 'assertions', result.assertions)

        if result.skipped?
          skipped = @doc.element('skipped')
          @doc.set_attr(skipped, 'message', result)
          @doc.add_text(skipped, '')
          @doc.add_child(testcase, skipped)
        else
          result.failures.each do |failure|
            failure_tag = @doc.element(classify(failure))
            @doc.set_attr(failure_tag, 'message', result)
            @doc.add_text(failure_tag, format_backtrace(failure))
            @doc.add_child(testcase, failure_tag)
          end
        end

        # Minitest 5.19 supports metadata
        # Rails 7.1 adds `failure_screenshot_path` to metadata
        # Output according to Gitlab format
        # https://docs.gitlab.com/ee/ci/testing/unit_test_reports.html#view-junit-screenshots-on-gitlab
        if result.respond_to?("metadata") && result.metadata[:failure_screenshot_path]
          screenshot = @doc.element("system-out")
          @doc.add_text(screenshot, "[[ATTACHMENT|#{result.metadata[:failure_screenshot_path]}]]")
          @doc.add_child(testcase, screenshot)
        end

        testcase
      end

      private

      def classify(failure)
        if failure.instance_of? UnexpectedError
          'error'
        else
          'failure'
        end
      end

      def working_directory
        @working_directory ||= Dir.getwd
      end

      def relative_to_cwd(path)
        path.sub(working_directory, '.')
      end

      def format_backtrace(failure)
        Minitest.filter_backtrace(failure.backtrace).map do |line|
          relative_to_cwd(line)
        end.join("\n")
      end

      def format_file(result)
        relative_to_cwd(result.source_location.first).sub(%r{\A\./}, "")
      end

      def format_class(result)
        if @options[:junit_jenkins]
          result.klass.to_s.gsub(/(.*)::(.*)/, '\1.\2')
        else
          fp = relative_to_cwd(result.source_location.first)
          fp.sub(%r{\.[^/]*\Z}, "").gsub("/", ".").gsub(%r{\A\.+|\.+\Z}, "")
        end
      end

      def format_name(result)
        result.name
      end

      def format_time(time)
        Kernel::format('%.6f', time)
      end
    end
  end
end

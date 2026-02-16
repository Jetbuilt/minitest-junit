require 'minitest/autorun'
require 'stringio'
require 'time'
require 'nokogiri'

require 'ox'
require 'rexml/document'
require 'minitest/junit'
require 'minitest/junit/xml_ox'
require 'minitest/junit/xml_nokogiri'
require 'minitest/junit/xml_rexml'

class FakeTestName; end

module ReporterTests
  def test_no_tests_generates_an_empty_suite
    reporter = create_reporter
    reporter.report

    parsed = Nokogiri::XML(reporter.output)
    testsuite = parsed.at_xpath('//testsuite')
    assert_equal 'minitest', testsuite['name']
    assert testsuite['timestamp']
    assert testsuite['hostname']
    assert_equal '0', testsuite['tests']
    assert_equal '0', testsuite['skipped']
    assert_equal '0', testsuite['failures']
    assert_equal '0', testsuite['errors']
    assert_equal '0.000000', testsuite['time']
  end

  # NOTE: This test will generate a temp file: "test/tmp/report.xml"
  def test_encoding
    file = File.new('test/tmp/report.xml', 'w:UTF-8')
    reporter = Minitest::Junit::Reporter.new file, { hostname: '‹foo›', document_class: document_class }
    reporter.start
    reporter.report
    file.close

    parsed = Nokogiri::XML(File.read('test/tmp/report.xml'))
    assert_equal '‹foo›', parsed.at_xpath('//testsuite')['hostname']
  end

  def test_formats_each_successful_result_with_a_formatter
    reporter = create_reporter

    results = do_formatting_test(reporter, count: rand(100), cause_failures: 0)

    parsed = Nokogiri::XML(reporter.output)
    results.each do |result|
      node = parsed.at_xpath("//testcase[@name='#{result.name}']")
      assert node, "Expected testcase with name #{result.name}"
      assert_equal 'FakeTestName', node['classname']
    end
  end

  def test_formats_each_failed_result_with_a_formatter
    reporter = create_reporter

    results = do_formatting_test(reporter, count: rand(100), cause_failures: 1)
    parsed = Nokogiri::XML(reporter.output)
    results.each do |result|
      assert parsed.at_xpath("//testcase[@name='#{result.name}']")
    end
    assert parsed.xpath("//testcase//failure").any?
    assert parsed.xpath("//testcase//system-out").any?
  end

  def test_xml_nodes_has_file_and_line_attributes
    reporter = create_reporter
    results = do_formatting_test(reporter, count: 2, cause_failures: 1)
    parsed = Nokogiri::XML(reporter.output)
    example_node = parsed.xpath("//testcase").first
    assert example_node.has_attribute?('file')
    assert example_node.has_attribute?('line')
    assert_equal 'unknown', example_node['file']
    assert_equal '-1', example_node['line']
  end

  private

  def document_class
    self.class::DOCUMENT_CLASS
  end

  def do_formatting_test(reporter, count: 1, cause_failures: 0)
    results = count.times.map do |i|
      result = create_test_result(methodname: "test_name#{i}", failures: cause_failures)
      reporter.record result
      result
    end

    reporter.report

    results
  end

  def create_test_result(name: FakeTestName, methodname: 'test_method_name', successes: 1, failures: 0)
    test = Class.new Minitest::Test do
      define_method 'class' do
        name
      end
    end.new methodname
    test.time = rand(100)
    test.assertions = successes + failures
    test.failures = failures.times.map do |i|
      Class.new Minitest::Assertion do
        define_method 'backtrace' do
          ["Model failure \##{i}", 'This is a test backtrace', "#{__FILE__}:#{__LINE__}"]
        end
      end.new
    end

    if failures.positive?
      test.metadata[:failure_screenshot_path] = '/tmp/screenshot.png'
    end

    Minitest::Result.from test
  end

  def create_reporter(options = {})
    io = StringIO.new
    reporter = Minitest::Junit::Reporter.new io, options.merge(document_class: document_class)
    def reporter.output
      @io.string
    end
    reporter.start
    reporter
  end
end

class ReporterTestOx < Minitest::Test
  DOCUMENT_CLASS = Minitest::Junit::OxDocument
  include ReporterTests
end

class ReporterTestNokogiri < Minitest::Test
  DOCUMENT_CLASS = Minitest::Junit::NokogiriDocument
  include ReporterTests
end

class ReporterTestRexml < Minitest::Test
  DOCUMENT_CLASS = Minitest::Junit::RexmlDocument
  include ReporterTests
end

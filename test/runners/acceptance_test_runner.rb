require 'json'
require 'fileutils'

ACCEPTANCE_SUITE_DIR = 'JSON-Schema-Test-Suite/tests'
# IMPLEMENTORS = ['json-schema (rb)', 'json-schema (python)', 'json-schema (go)', 'json-schema (node)', 'json-schema (blah)']
IMPLEMENTORS = ['json-schema (rb)']
class AcceptanceTestRunner
  def initialize
    @test_options = []
    @test_file = StringIO.new
    @test_file.puts """
    RSpec.configure do |config|
      config.matrix_implementors = #{IMPLEMENTORS.inspect}
    end

    require 'json-schema'
    def validate_schema schema, data
      JSON::Validator.validate schema, data
    end
    """
  end

  def parse_test_dir dir
    Dir.glob("#{dir}/*").each do |f|
      suite_name = File.basename(f, '.json')
      options = @test_options[1..-2]
      @test_file.puts "describe '#{suite_name}', :options => #{options.inspect} do"
      @test_options.push << suite_name
      if File.file?(f)
        parse_test_file f
      elsif File.directory?(f)
        parse_test_dir f
      end
      @test_file.puts "end"
      @test_options.pop
    end
  end

  def write_test_file f
    FileUtils.mkdir_p File.dirname(f)
    File.open(f, 'wb') {|f| f.write @test_file.string }
  end

  private

  def create_schema_file schema
    file = File.join 'tmp', 'schemas', "#{SecureRandom.uuid}.json"
    FileUtils.mkdir_p 'tmp/schemas'
    File.open(file, 'wb') {|f| f.write schema}
    file
  end
  
  def parse_test_file f
    product = @test_options[0]
    feature = @test_options[-1]
    options = @test_options[1..-2]
    test_suite = JSON.parse(File.read f)
    test_suite.each do |scenarios|
      description = scenarios['description']
      # schema_file = create_schema_file scenarios['schema']
      schema = scenarios['schema']
      @test_file.puts "describe #{description.inspect} do"
      @test_file.puts "let (:schema) { #{schema.inspect} }"
      scenarios['tests'].each do |scenario|
        description = scenario['description']
        data = scenario['data']
        @test_file.puts "describe #{description.inspect} do"
        @test_file.puts "let (:data) { #{data.inspect} }"
        IMPLEMENTORS.each do |imp|
          @test_file.puts "it '#{imp}' do"
          @test_file.puts "validity = validate_schema schema, data"
          @test_file.puts "expect(validity).to be_#{scenario['valid']}"
          @test_file.puts "end"
        end
        @test_file.puts "end"
      end
      @test_file.puts "end"
    end
  end
end

test_runner = AcceptanceTestRunner.new
test_runner.parse_test_dir ACCEPTANCE_SUITE_DIR
test_runner.write_test_file 'tmp/spec/acceptance_spec.rb'
# test_runner.run

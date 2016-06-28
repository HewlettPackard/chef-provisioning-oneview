require 'json'

# Helper for mocking responses
class FakeResponse
  attr_reader :body, :code, :header

  def initialize(body = {}, code = 200, header = {})
    @body = body
    @body = @body.to_json unless @body.class == String
    @code = code
    @header = header
  end

  def[](key)
    header[key]
  end

  def to_hash
    header
  end
end

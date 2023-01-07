class ListError

  # General Errors
  class Generic < StandardError
  end

  # Bad Request Errors
  class BadRequest < Generic
  end

  class Validation < BadRequest
  end

  # Not Found Errors
  class NotFound < Generic
  end

  # Internal Server Errors
  class InternalServer < Generic
  end

end
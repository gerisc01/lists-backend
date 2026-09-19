class ListError

  class Generic < StandardError
  end

  class BadRequest < Generic
  end

  class Validation < BadRequest
  end

  class NotFound < Generic
  end

  class InternalServer < Generic
  end

end
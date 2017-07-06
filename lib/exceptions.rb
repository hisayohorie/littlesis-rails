module Exceptions
  class PermissionError < StandardError; end
  class NotFoundError < StandardError; end
  class MissingApiTokenError < StandardError; end
  class RestrictedUserError < StandardError; end
end

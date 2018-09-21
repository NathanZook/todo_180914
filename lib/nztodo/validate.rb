module NZTodo
  module RequestException

    def initialize(message)
      super(message.to_json)
    end

    def http_status
      self.class::Code
    end
  end

  class BadRequest < RuntimeError
    include RequestException
    Code = 400
  end
  
  class NotFound < RuntimeError
    include RequestException
    Code = 404
  end
  
  class Conflict < RuntimeError
    include RequestException
    Code = 409
  end

  module Validate
    class << self
      UUIDRegexp = /^[0-9a-f]{8}\-[0-9a-f]{4}\-[0-9a-f]{4}\-[0-9a-f]{4}\-[0-9a-f]{12}$/

      def check_condition(condition, fail_message_parts, error_class = BadRequest)
        fail_message_parts = [fail_message_parts] unless fail_message_parts.is_a?(Array)
        fail_message = "#{fail_message_parts * ' '}."
        condition or raise error_class, fail_message
      end

      def data_type_error_message(key, klass)
        ["Value for #{key} must be a #{klass}"]
      end 

      def class_check(data, klass, key)
        check_condition(data.is_a?(klass), data_type_error_message(key, klass.name.downcase))
      end

      def check_bool(data, key)
        check_condition([true, false].include?(data), data_type_error_message(key, 'boolean'))
      end

      def check_uint32_string(data, key)
        test = data.is_a?(String) && /^([0-9]+|0x[0-9a-f]+|0[0-7]+|0b[01]+)$/.match?(data) && (0 ... 1<<32).include?(data.to_i)
        check_condition(test, data_type_error_message(key, 'uint32 string'))
      end

      def check_uuid(data, key)
        test = data.is_a?(String) && (data.downcase! ; data =~ UUIDRegexp)
        check_condition(test, data_type_error_message(key, 'uuid'))
      end

      def validate_form(data, specs)
        class_check(data, Hash, 'data')

        bad_keys = data.keys - specs.keys
        check_condition(bad_keys.empty?, ["Unexpected key(s):", bad_keys])

        bad_keys = specs.keys - data.keys
        check_condition(bad_keys.empty?, ["Missing required key(s):", bad_keys])
      end

      def fetch(hash, id, object_type)
        check_uuid(id, "#{object_type.downcase} id")
        check_condition(hash.has_key?(id), ["#{object_type} not found"], NotFound)
        hash[id]
      end

      def validate_arg(value, key, spec)
        if spec.is_a?(Class)
          class_check(value, spec, key)
        else
          send("check_#{spec}", value, key)
        end
      end

      def validate_data(data, specs)
        validate_form(data, specs)
        data.each do |key, value|
          validate_arg(value, key, specs[key])
        end
      end
    end
  end
end


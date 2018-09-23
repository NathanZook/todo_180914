require 'json'
require 'nztodo/validate'

module NZTodo
  RSpec.describe(Validate) do

    let(:key) {'key'}
    let(:item_id) { 'd94d1929-4d65-4a96-959a-4fffe1aaa83e' }

    # The validate module was built from the bottom up post-spike.  All of the
    # tests before validate_arg are repeated in the final tests, but they are
    # left here because they are cheap & might aid debugging.  Any significant
    # refactoring will likely blow these away.

    context 'when check_condition is called with a false condition' do
      let(:message_head) {'Head'}
      let(:message_tail) {'tail'}
      let(:message_out) { "#{message_head} #{message_tail}."}

      it 'raises a BadRequest if no error class is passed' do
        expect{Validate.check_condition(false, [message_head, message_tail])}.to raise_error(BadRequest)
      end

      it 'the exception has sensible message' do
        expect{Validate.check_condition(false, [message_head, message_tail])}.to raise_error(BadRequest, message_out.to_json)
      end

      it 'raises whatever class of error it is passed' do
        message_parts = [message_head, message_tail]
        expect{Validate.check_condition(false, message_parts, NotFound)}.to raise_error(NotFound, message_out.to_json)
      end
    end

    context 'when check_condition is called with a true condition' do
      let(:message) {'Head'}

      it 'does not raise'do
        expect{Validate.check_condition(true, message)}.to_not raise_error
      end
    end

    context 'when class_check is called' do
      let(:test_class_name) {'TestClass'}
      let(:test_predicate) {true}
      let(:tail_message) {"must be a #{test_class_name.downcase}"}

      before do
        @test_Validate = double("test Validate", :is_a? => test_predicate)
        @test_class = instance_double("Class", :name => test_class_name)
      end

      it 'calls is_a? on the Validate with the class' do
        expect(@test_Validate).to receive(:is_a?).with(@test_class)
        Validate.class_check(@test_Validate, @test_class, key)
      end

      it 'calls check_condition with the test predicate, key, and a sensible message' do
        expect(Validate).to receive(:check_condition).with(test_predicate, ["Value for #{key} #{tail_message}"])
        Validate.class_check(@test_Validate, @test_class, key)
      end
    end

    context 'when check_bool is called' do
      let(:bool_message) { "must be a JSON boolean" }

      it 'calls check_condition with "true", the key, and a sensible message when passed "true" and a key' do
        expect(Validate).to receive(:check_condition).with(true, ["Value for #{key} must be a boolean"])
        Validate.check_bool(true, key)
      end

      it 'calls check_condition with "true", the key, and a sensible message when passed "false" and a key' do
        expect(Validate).to receive(:check_condition).with(true, ["Value for #{key} must be a boolean"])
        Validate.check_bool(false, key)
      end

      it 'calls check_condition with "false", the key, and a senible message otherwise' do
        expect(Validate).to receive(:check_condition).with(false, ["Value for #{key} must be a boolean"])
        Validate.check_bool(nil, key)
      end
    end

    context 'when check_uint32_string is called, it' do
      [
        [false, 'a float', '1.0'],
        [false, 'a negative number', '-1'],
        [false, 'a large number', (1 << 32).to_s],
        [true, '0', '0'],
        [true, 'MAX_UINT32', ((1 << 32) - 1).to_s],
        [true, 'hex strings', '0x%x' % 496],
        [true, 'octal strings', '0%o' % 8128],
        [true, 'binary strings', '0b%b' % 33550336],
      ].each do |predicate, description, value|
        it "calls check_condtion with \"#{predicate}\", the key, and a sensible message when passed #{description}" do
          expect(Validate).to receive(:check_condition).with(predicate, ["Value for #{key} must be a uint32 string"])
          Validate.check_uint32_string(value, key)
        end
      end
    end

    context 'when check_valid_form is called' do
      let(:data) { {'a' => 1, 'b' => 'c'} }
      let(:argspecs) { {'a' => :uint32, 'b' => String} }
      it 'passes valid forms' do
        expect{Validate.validate_form(data, argspecs)}.to_not raise_error
      end

      it 'fails when data not a hash' do
        expect{Validate.validate_form([], argspecs)}.to raise_error(BadRequest, "Value for data must be a hash.".to_json)
      end

      # As of Ruby 1.9, hashes retain the order of their keys.  I do not approve, but I keep my code simple.
      it 'fails if there are no unexpected keys' do
        data['z'] = true
        data['y'] = 'a string'
        expect{Validate.validate_form(data, argspecs)}.to raise_error(BadRequest, "Unexpected key(s): z y.".to_json)
      end

      it 'fails if there are missing keys' do
        data = {}
        expect{Validate.validate_form(data, argspecs)}.to raise_error(BadRequest, "Missing required key(s): a b.".to_json)
      end
    end

    context 'when validate_arg is called' do
      it 'fails on a class mismatch' do
        expect{Validate.validate_arg(true, key, String)}.to raise_error(BadRequest, "Value for #{key} must be a string.".to_json)
      end

      it 'passes a class match' do
        expect{Validate.validate_arg('a', key, String)}.to_not raise_error
      end

      it 'fails a non-boolean for a boolean check' do
        expect{Validate.validate_arg(nil, key, :bool)}.to raise_error(BadRequest, "Value for #{key} must be a boolean.".to_json)
      end

      it 'passes true for a boolean check' do
        expect{Validate.validate_arg(true, key, :bool)}.to_not raise_error
      end

      it 'passes false for a boolean check' do
        expect{Validate.validate_arg(false, key, :bool)}.to_not raise_error
      end

      context 'when checking uint32_string' do
        [
          ["a float", '1.0'],
          ["a negative number", '-1'],
          ["a large number", (1 << 32).to_s],
          ["not a string", 5],
        ].each do |description, value|
          it "fails #{description}" do
            message = "Value for #{key} must be a uint32 string.".to_json
            expect{Validate.validate_arg(value, key, :uint32_string)}.to raise_error(BadRequest, message)
          end
        end

        [
          ['0', '0'],
          ['MAX_UINT32', ((1 << 32) - 1).to_s],
          ['hex strings', '0x%x' % 496],
          ['octal strings', '0%o' % 8128],
          ['binary strings', '0b%b' % 33550336],
        ].each do |description, value|
          it "passes #{description}" do
            expect{Validate.validate_arg(value, key, :uint32_string)}.to_not raise_error
          end
        end
      end

      context 'when checking uuid' do
        it 'fails if the data is not a string' do
          expect{Validate.validate_arg(1, key, :uuid)}.to raise_error(BadRequest, "Value for #{key} must be a uuid.".to_json)
        end

        it 'fails if the data is malformed' do
          message = "Value for #{key} must be a uuid.".to_json
          expect{Validate.validate_arg('abc123', key, :uuid)}.to raise_error(BadRequest, message)
        end

        it 'passes if the data is a uuid' do
          expect{Validate.validate_arg(item_id, key, :uuid)}.to_not raise_error
        end

        it 'passes if the data is a capitalized uuid' do
          expect{Validate.validate_arg(item_id.upcase, key, :uuid)}.to_not raise_error
        end

        it 'downcases a capitalized uuid' do
          upcase = item_id.upcase
          Validate.validate_arg(upcase, key, :uuid)
          expect(upcase).to eq(item_id)
        end
      end
    end

    context 'when validate_data is called' do
      let(:data) { {'a' => true, 'b' => 'a string', 'c' => [], 'd' => '1'} }
      let(:spec) { {'a' => :bool, 'b' => String, 'c' => Array, 'd' => :uint32_string} }


      #WARNING:  This definition will NOT decend into nested contexts.  If this becomes needed, pull into a module

      it 'is happy when all is good' do
        expect{Validate.validate_data(data, spec)}.to_not raise_error
      end

      [
        ['data is not a hash', Proc.new{|d| []}, 'Value for data must be a hash.'],
        ['values are missing', Proc.new{|d| d.delete('b') ; d.delete('c') ; d}, 'Missing required key(s): b c.'],
        ['unexpected values', Proc.new{|d| d['z'] = 'y' ; d}, 'Unexpected key(s): z.'],
        ['a value fails its type check', Proc.new{|d| d['a'] = 5 ; d}, 'Value for a must be a boolean.'],
      ].each do |description, mutation, error_string|
        it "raises when #{description}" do
          bad_data = mutation.call(data)
          expect{Validate.validate_data(bad_data, spec)}.to raise_error(BadRequest, error_string.to_json)
        end
      end
    end

    context 'fetch' do
      let(:thingy) { 'a thingy' }
      let(:hash) { {item_id => thingy} }
      it 'returns found data' do
        expect(Validate.fetch(hash, item_id, 'Thing')).to eq(thingy)
      end

      it 'raises appropriately if the key is not a uuid' do
        expect{Validate.fetch(hash, 1, 'Thing')}.to raise_error(BadRequest, 'Value for thing id must be a uuid.'.to_json)
      end

      it 'raises appropriately if the data is not found' do
        expect{Validate.fetch({}, item_id, 'Thing')}.to raise_error(NotFound, "Thing not found.".to_json)
      end
    end
  end
end



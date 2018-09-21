module NZTodo
  class Task
    class << self
      def list(id)
        List.retrieve(id)
      end

      def normalize(data)
        data.replace({'completed' => false}.merge(data)) if data.is_a?(Hash)
        Validate.validate_data(data, {'name' => String, 'completed' => :bool})
      end

      def build(data, task_list, task_hash)
        uuid = UUID.new(task_hash)
        new(uuid, data['name'], data['completed'], task_list, task_hash)
      end

      def create(list_id, data)
        normalize(data)
        task = list(list_id).add_task(data)
        task.id
      end

      def retrieve(list_id, id)
         list(list_id).retrieve(id)
      end

      def complete(list_id, id, data)
        Validate.validate_data(data, 'completed' => :bool)
        list = list(list_id)
        task = list.retrieve(id)
        task.completed = data['completed']
        task
      end
    end

    attr_reader :id, :name
    attr_accessor :completed
    def initialize(id, name, completed, task_list, task_hash)
      @id, @name, @completed = id, name, completed
      task_list << self
      task_hash[@id] = self
    end

    def as_json()
      {'id' => @id, 'name' => @name, 'completed' => @completed}
    end

    def to_json(*a)
      as_json.to_json(*a)
    end
  end
end

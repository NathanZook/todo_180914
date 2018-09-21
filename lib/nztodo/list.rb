module NZTodo
  class List
    @lists = {}
    @lists_list = []
 
    class << self
      def exists?(id)
        @lists.has_key?(id)
      end

      def matching_lists(search_string)
        @lists_list.select{|list| list.name[search_string]}
      end

      def normalize(data)
        data.replace({'description' => '', 'tasks' => []}.merge(data)) if data.is_a?(Hash)
        Validate.validate_data(data, {'name' => String, 'description' => String, 'tasks' => Array})
        data['tasks'].each{|task_data| Task.normalize(task_data)}
      end

      def build(data)
        id = UUID.new(@lists)
        list = new(id, data['name'], data['description'], data['tasks'], @lists, @lists_list)
        [list.id, list.tasks.map{|task| task.id}]
      end

      def retrieve(id)
        Validate.fetch(@lists, id, 'List')
      end

      def create(data)
        normalize(data)
        build(data)
      end

      def list(params)
        params = {'skip' => '0', 'limit' => @lists_list.length.to_s, 'search' => ''}.merge(params) if params.is_a?(Hash)
        Validate.validate_data(params, {'skip' => :uint32_string, 'limit' => :uint32_string, 'search' => String})
        search_string = params['search']
        search_list = search_string == '' ? @lists_list : matching_lists(search_string)
        search_list[params['skip'].to_i, params['limit'].to_i]
      end
    end

    attr_reader :id, :name, :tasks

    def initialize(id, name, description, tasks_data, list_hash, list_list)
      @id, @name, @description = id, name, description
      @tasks = []
      @tasks_hash = {}
      tasks_data.each{|task_data| add_task(task_data)}
      list_hash[id] = self
      list_list << self
    end

    def add_task(task_data)
      Task.build(task_data, @tasks, @tasks_hash)
    end

    def retrieve(task_id)
      Validate.fetch(@tasks_hash, task_id, 'Task')
    end

    def as_json()
      {'id' => @id, 'name' => @name, 'description' => @description, 'tasks' => @tasks}
    end

    def to_json(*a)
      as_json.to_json(*a)
    end
  end
end


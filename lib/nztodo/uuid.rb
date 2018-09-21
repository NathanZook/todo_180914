module NZTodo
  module UUID
    def self.new(hash)
      # Yes, I worked at Google...
      begin 
        uuid = SecureRandom.uuid
      end until !hash.has_key?(uuid)
      uuid
    end
  end
end


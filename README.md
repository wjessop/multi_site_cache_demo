# Multi site cache

POC to show possible replication of cache access between multiple datacentres. It works, but probably needs finessing. Uses a size limited queue and a background process to mirror cache operations to a remote, probably slower, location

To run the example spin up two redis servers on ports 5000 and 5001 (I chose redis so you can run redis-cli and monitor, but you could use Dalli memcached objects too), then curl curl localhost:3000/.

production/development.rb

````ruby
config.cache_store = MultiSiteCache.new({
  :max_queue_size => 5000, # Or something
  :stores => {
    "sc-chi" => [:redis_store, "redis://localhost:5000/0/cache"],
    "rw-ash" => [:redis_store, "redis://localhost:5001/0/cache"]
  }
})
config.action_controller.perform_caching = true
````

lib/multi_site_cache.rb:

````ruby
require 'thread'

# This is a POC to show an idea and not the end implementation
# It may be missing syncronisation and methds we need such as
# increment/decrement

class MultiSiteCache
  # attr_reader :stores

  def initialize(options = {})
    @max_queue_size = options[:max_queue_size] || raise(ArgumentError, "Must specify a max write queue size")

    # Could have sworn that there was a non-blocking push for SizedQueue
    # but apparently not. As that's not the case we need to check the
    # size of the queue before pushing so may as use a regular Queue
    # Pfft, Ruby.
    @remote_operations_queue = Queue.new
    @worker_thread = Thread.new {
      loop do
        meth, args, block = @remote_operations_queue.pop
        remote_store.send(meth, *args, &block)
      end
    }

    @stores = {}
    options.fetch(:stores, {}).map do |dc, o|
      @stores[dc] = ActiveSupport::Cache.lookup_store(*o)
    end
  end

  protected

  def method_missing(meth, *args, &block)
    # If I had time I'd work out why the remote_store complains about this and why I need it
    return local_store.send(meth, args, &block) if meth == :to_ary

    @remote_operations_queue.push([meth, args, block]) unless @remote_operations_queue.size >= @max_queue_size
    local_store.send(meth, args, &block)
  end

  private

  # Obvs work these out dynamically
  def local_store
    @stores["sc-chi"]
  end

  def remote_store
    @stores["rw-ash"]
  end
end
````

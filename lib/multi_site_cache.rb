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

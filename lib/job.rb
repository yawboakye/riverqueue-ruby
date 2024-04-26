module River
  JOB_STATE_AVAILABLE = "available"
  JOB_STATE_CANCELLED = "cancelled"
  JOB_STATE_COMPLETED = "completed"
  JOB_STATE_DISCARDED = "discarded"
  JOB_STATE_RETRYABLE = "retryable"
  JOB_STATE_RUNNING = "running"
  JOB_STATE_SCHEDULED = "scheduled"

  # Provides a way of creating a job args from a simple Ruby hash for a quick
  # way to insert a job without having to define a class. The first argument is
  # a "kind" string for identifying the job in the database and the second is a
  # hash that will be encoded to JSON.
  class JobArgsHash
    def initialize(kind, hash)
      raise "kind should be non-nil" if !kind
      raise "hash should be non-nil" if !hash

      @kind = kind
      @hash = hash
    end

    attr_reader :kind

    def to_json
      JSON.dump(@hash)
    end
  end

  # JobRow contains the properties of a job that are persisted to the database.
  class JobRow
    # ID of the job. Generated as part of a Postgres sequence and generally
    # ascending in nature, but there may be gaps in it as transactions roll
    # back.
    attr_accessor :id

    # The job's args as a hash decoded from JSON.
    attr_accessor :args

    # The attempt number of the job. Jobs are inserted at 0, the number is
    # incremented to 1 the first time work its worked, and may increment further
    # if it's either snoozed or errors.
    attr_accessor :attempt

    # The time that the job was last worked. Starts out as `nil` on a new
    # insert.
    attr_accessor :attempted_at

    # The set of worker IDs that have worked this job. A worker ID differs
    # between different programs, but is shared by all executors within any
    # given one.  (i.e. Different Go processes have different IDs, but IDs are
    # shared within any given process.) A process generates a new ULID (an
    # ordered UUID) worker ID when it starts up.
    attr_accessor :attempted_by

    # When the job record was created.
    attr_accessor :created_at

    # A set of errors that occurred when the job was worked, one for each
    # attempt.  Ordered from earliest error to the latest error.
    attr_accessor :errors

    # The time at which the job was "finalized", meaning it was either completed
    # successfully or errored for the last time such that it'll no longer be
    # retried.
    attr_accessor :finalized_at

    # Kind uniquely identifies the type of job and instructs which worker
    # should work it. It is set at insertion time via `#kind` on job args.
    attr_accessor :kind

    # The maximum number of attempts that the job will be tried before it errors
    # for the last time and will no longer be worked.
    attr_accessor :max_attempts

    # The priority of the job, with 1 being the highest priority and 4 being the
    # lowest. When fetching available jobs to work, the highest priority jobs
    # will always be fetched before any lower priority jobs are fetched. Note
    # that if your workers are swamped with more high-priority jobs then they
    # can handle, lower priority jobs may not be fetched.
    attr_accessor :priority

    # The name of the queue where the job will be worked. Queues can be
    # configured independently and be used to isolate jobs.
    attr_accessor :queue

    # When the job is scheduled to become available to be worked. Jobs default
    # to running immediately, but may be scheduled for the future when they're
    # inserted. They may also be scheduled for later because they were snoozed
    # or because they errored and have additional retry attempts remaining.
    attr_accessor :scheduled_at

    # The state of job like `available` or `completed`. Jobs are `available`
    # when they're first inserted.
    attr_accessor :state

    # Tags are an arbitrary list of keywords to add to the job. They have no
    # functional behavior and are meant entirely as a user-specified construct
    # to help group and categorize jobs.
    attr_accessor :tags

    def initialize(
      id:,
      args:,
      attempt:,
      created_at:,
      kind:,
      max_attempts:,
      priority:,
      queue:,
      scheduled_at:,
      state:,

      # nullable/optional
      attempted_at: nil,
      attempted_by: nil,
      errors: nil,
      finalized_at: nil,
      tags: nil
    )
      self.id = id
      self.args = args
      self.attempt = attempt
      self.attempted_at = attempted_at
      self.attempted_by = attempted_by
      self.created_at = created_at
      self.errors = errors
      self.finalized_at = finalized_at
      self.kind = kind
      self.max_attempts = max_attempts
      self.priority = priority
      self.queue = queue
      self.scheduled_at = scheduled_at
      self.state = state
      self.tags = tags
    end
  end

  # A failed job work attempt containing information about the error or panic
  # that occurred.
  class AttemptError
    # The time at which the error occurred.
    attr_accessor :at

    # The attempt number on which the error occurred (maps to #attempt on a job
    # row).
    attr_accessor :attempt

    # Contains the stringified error of an error returned from a job or a panic
    # value in case of a panic.
    attr_accessor :error

    # Contains a stack trace from a job that panicked. The trace is produced by
    # invoking `debug.Trace()`.
    attr_accessor :trace

    def initialize(
      at:,
      attempt:,
      error:,
      trace:
    )
      self.at = at
      self.attempt = attempt
      self.error = error
      self.trace = trace
    end
  end
end

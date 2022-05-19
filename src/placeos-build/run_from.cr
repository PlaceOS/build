require "./error"

module RunFrom
  record Result,
    status : Process::Status,
    output : IO::Memory

  def self.run_from(path, command, args, timeout : Time::Span = 1.5.minutes, **rest)
    # Run in a different thread to prevent blocking
    channel = Channel(Process::Status).new(capacity: 1)
    output = IO::Memory.new
    trace = OpenTelemetry.trace
    spawn(same_thread: false) do
      status = trace.in_span("Run `#{command}`") do
        Process.run(
          command,
          **rest,
          args: args,
          input: Process::Redirect::Close,
          output: output,
          error: output,
          chdir: path,
          clear_env: true, # May be an issue if dependent on proxy environment variable
        )
      end

      channel.send(status)
    end

    select
    when status = channel.receive
    when timeout(timeout)
      raise PlaceOS::Build::Error.new("Running #{command} timed out after #{timeout.total_seconds}s")
    end

    Result.new(status, output)
  end
end

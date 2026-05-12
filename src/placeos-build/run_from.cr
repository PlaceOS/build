require "./error"

module RunFrom
  record Result,
    status : Process::Status,
    output : IO::Memory

  def self.run_from(path, command, args, timeout : Time::Span = 10.minutes, **rest)
    # Run in a different thread to prevent blocking
    channel = Channel(Process::Status | Exception).new(capacity: 1)
    output = IO::Memory.new
    process = nil

    spawn(same_thread: true) do
      begin
        process = Process.new(
          command,
          **rest,
          args: args,
          input: Process::Redirect::Close,
          output: output,
          error: output,
          chdir: path,
        )

        status = process.as(Process).wait
        channel.send(status) unless channel.closed?
      rescue e
        # Surface spawn failures (EMFILE on pipe(), missing binary, chdir errors,
        # etc.) immediately instead of letting the caller wait the full `timeout`.
        channel.send(e) rescue nil
      end
    end

    select
    when result = channel.receive
      channel.close

      case result
      in Process::Status
        Result.new(result, output)
      in Exception
        raise PlaceOS::Build::Error.new(
          "Failed to launch #{command}: #{result.class}: #{result.message}\n#{output}",
          cause: result,
        )
      end
    when timeout(timeout)
      channel.close
      begin
        process.try(&.terminate)
      rescue RuntimeError
        # Ignore missing process
      end

      raise PlaceOS::Build::Error.new("Running #{command} timed out after #{timeout.total_seconds}s with:\n#{output}")
    end
  end
end

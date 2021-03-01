require "digest/sha1"
require "compiler/crystal/**"

module PlaceOS::Build
  Log = ::Log.for(self)

  def source_hash(path : String | Path)
    validate_compiler_env!

    # Compile and write output to /dev/null (or equivalent)
    result = ::Crystal::Program.new.host_compiler.compile(source: ::Crystal::Compiler::Source.new(path, File.read(path)), output_filename: File::NULL)
    # Calculate SHA-1 hash of entrypoint's requires
    Log.debug { "digesting #{path}" }
    sha = result.program.requires.each_with_object(::Digest::SHA1.new) do |file, digest|
      puts "> #{file}"
      digest.file(file)
    end

    # Include the entrypoint in the hash
    sha.file(path)

    sha.final.hexstring
  end

  private def validate_compiler_env!
    {"CRYSTAL_PATH", "CRYSTAL_LIBRARY_PATH"}.each do |key|
      ENV[key]? || abort("#{key} not present in environment")
    end
    nil
  end
end

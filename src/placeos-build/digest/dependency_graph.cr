# Pulled from [`scry`](https://github.com/crystal-lang-tools/scry/)
#
module DependencyGraph
  def self.requires(entrypoint) : Set(String)
    DependencyGraph::Builder.new([entrypoint.to_s])
      .build
      .nodes
      .keys
      .to_set
  end

  class_getter default_crystal_path : String do
    # Mimic the behavior of Crystal::CrystalPath.default_path
    # instead of requiring "compiler/crystal/crystal_path" which gives a lot
    # a require issues...
    default_path = ENV["CRYSTAL_PATH"]? || ENV["CRYSTAL_CONFIG_PATH"]? || ""

    default_path.split(':').each do |path|
      if File.exists?(File.expand_path("prelude.cr", path))
        return path
      end
    end

    ""
  end

  class Graph
    record Node, value : String, connections : Set(Node) = Set(Node).new do
      def_hash value

      def descendants
        # Returns all the connections (first-degree and more) of this node.
        visit = connections.to_a
        visited = Set(Node).new
        while visit.size != 0
          check = visit.pop
          visited << check
          check.connections.reject { |e| visited.includes?(e) }.each { |e| visit << e }
        end
        visited
      end
    end

    getter prelude_node : Node

    getter nodes : Hash(String, Node)

    def initialize(@nodes = {} of String => Node)
      prelude_path = File.expand_path("prelude.cr", DependencyGraph.default_crystal_path)
      nodes[prelude_path] = @prelude_node = Node.new(prelude_path)
    end

    def add_edge(value_1 : String, value_2 : String)
      add value_1
      add value_2
      nodes[value_1].connections << nodes[value_2]
    end

    def add(value : String)
      nodes[value] = Node.new(value) unless nodes[value]?
    end

    delegate each, delete, :[], :[]?, to: nodes
  end

  class Builder
    def initialize(@lookup_paths : Array(String))
    end

    def build
      Log.trace { "building dependency graph for #{@lookup_paths.join(", ")}" }
      graph = Graph.new
      @lookup_paths
        .map { |e| Dir.exists?(e) ? File.join(File.expand_path(e), "**", "*.cr") : File.expand_path(e) }
        .uniq!
        .flat_map { |d| Dir.glob(d) }
        .each { |file| process_requires(file, graph) }

      prelude_node = graph.prelude_node
      graph.each.reject { |e| e == prelude_node.value }.each do |key, _|
        graph[key].connections << prelude_node
      end
      graph
    end

    def rebuild(graph, filename)
      process_requires(filename, graph)
      graph
    end

    def process_requires(file, graph)
      requires = parse_requires(file)
      current_file_path = File.expand_path(file)
      if (requires.empty?)
        graph.add(current_file_path)
        return
      end
      requires_so_far = [] of String
      requires.each do |required_file_path|
        if required_file_path.nil?
          next
        elsif required_file_path.ends_with?("*.cr")
          Dir.glob(required_file_path).sort.each do |p|
            graph.add_edge(current_file_path, p)
            requires_so_far.each { |pp| graph.add_edge(p, pp) }
            requires_so_far << p
          end
        else
          graph.add_edge(current_file_path, required_file_path)
          requires_so_far.each do |path|
            graph.add_edge(required_file_path, path)
          end
          requires_so_far << required_file_path
        end
      end
    end

    def parse_requires(file_path)
      file_dir = File.dirname(file_path)
      paths = [] of String
      File.each_line(file_path) do |line|
        require_statement = /^\s*require\s*\"(?<file>.*)\"\s*$/.match(line)
        unless require_statement.nil?
          path = resolve_path(require_statement.as(Regex::MatchData)["file"].not_nil!, file_dir)
          if path
            paths << path
          end
        end
      end
      paths
    end

    def resolve_path(required_file, file_dir)
      if required_file.starts_with?(".")
        "#{File.expand_path(required_file, file_dir)}.cr"
      else
        @lookup_paths.each do |e|
          path = "#{File.expand_path(required_file, e)}.cr"
          return path if File.exists?(path)
        end
      end
    end
  end
end

module Minitest
  module Junit
    class RexmlDocument
      def document
        doc = REXML::Document.new
        doc << REXML::XMLDecl.new('1.0', 'UTF-8')
        doc
      end

      def element(name)
        REXML::Element.new(name)
      end

      def set_attr(el, name, value)
        el.add_attribute(name, value.to_s)
      end

      def add_child(parent, child)
        parent << child
      end

      def add_text(el, text)
        el.add_text(text.to_s)
      end

      def dump(doc)
        output = String.new
        formatter = REXML::Formatters::Pretty.new(2)
        formatter.compact = true
        formatter.write(doc, output)
        output << "\n"
      end
    end
  end
end

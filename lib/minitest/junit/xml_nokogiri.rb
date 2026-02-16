module Minitest
  module Junit
    class NokogiriDocument
      def document
        @doc = Nokogiri::XML::Document.new
        @doc.encoding = 'UTF-8'
        @doc
      end

      def element(name)
        Nokogiri::XML::Node.new(name, @doc)
      end

      def set_attr(el, name, value)
        el[name.to_s] = value.to_s
      end

      def add_child(parent, child)
        parent << child
      end

      def add_text(el, text)
        el.content = text.to_s
      end

      def dump(doc)
        doc.to_xml(indent: 2)
      end
    end
  end
end

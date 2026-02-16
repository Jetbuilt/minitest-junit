module Minitest
  module Junit
    class OxDocument
      def document
        doc = Ox::Document.new(version: '1.0', encoding: 'UTF-8')
        instruct = Ox::Instruct.new(:xml)
        instruct[:version] = '1.0'
        instruct[:encoding] = 'UTF-8'
        doc << instruct
        doc
      end

      def element(name)
        Ox::Element.new(name)
      end

      def set_attr(el, name, value)
        el[name] = value
      end

      def add_child(parent, child)
        parent << child
      end

      def add_text(el, text)
        el << text.to_s
      end

      def dump(doc)
        Ox.dump(doc)
      end
    end
  end
end

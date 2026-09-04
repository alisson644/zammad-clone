# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

Rspec.shared_examples 'HasImageSanitizeNote' do |model_factory:|
  describe 'Image prevention' do
    context 'with inline image' do
      subject do
        create(model_factory,
               note: 'test 123 <img src="asd.jpg"><img src="data:image/jpeg;base64,/9j/4AAQ..."><b>some text</b>')
      end

      before do
        # XSS processing may run into a timeout on slow CI systems, so turn the timeout off for the test.
        stub_const("#{HtmlSanitizer}::PROCESSING_TIMEOUT", nil)
      end

      it 'strips out <img> tags' do
        expect(subject.note).to eq('test 123 <b>some text</b>')
      end
    end
  end
end

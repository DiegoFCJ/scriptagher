import { CommonModule } from '@angular/common';
import { Component, Signal, computed, signal } from '@angular/core';

@Component({
  selector: 'app-pdf-to-txt',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './pdf-to-txt.component.html',
  styleUrls: ['./pdf-to-txt.component.scss']
})
export class PdfToTxtComponent {
  readonly selectedFile = signal<File | null>(null);
  readonly extractedText = signal<string>('');
  readonly isProcessing = signal<boolean>(false);
  readonly errorMessage = signal<string>('');
  readonly processedPages = signal<number>(0);
  readonly totalPages = signal<number>(0);

  readonly hasText: Signal<boolean> = computed(() => this.extractedText().length > 0);

  readonly progressLabel: Signal<string> = computed(() => {
    const total = this.totalPages();
    const processed = this.processedPages();
    if (!total) {
      return '';
    }
    if (processed >= total) {
      return `Conversione completata (${total} pagine)`;
    }
    return `Conversione in corso: pagina ${processed + 1} di ${total}`;
  });

  async onFileSelected(event: Event): Promise<void> {
    const input = event.target as HTMLInputElement;
    const file = input.files && input.files.length > 0 ? input.files[0] : null;
    if (!file) {
      return;
    }
    await this.handleFile(file);
    input.value = '';
  }

  async handleFile(file: File): Promise<void> {
    this.selectedFile.set(file);
    this.extractedText.set('');
    this.errorMessage.set('');
    this.processedPages.set(0);
    this.totalPages.set(0);
    this.isProcessing.set(true);

    try {
      const { getDocument, GlobalWorkerOptions, version } = await import('pdfjs-dist');

      if (!GlobalWorkerOptions.workerSrc) {
        GlobalWorkerOptions.workerSrc = `https://cdnjs.cloudflare.com/ajax/libs/pdf.js/${version}/pdf.worker.min.js`;
      }

      const arrayBuffer = await file.arrayBuffer();
      const loadingTask = getDocument({ data: arrayBuffer });
      const pdf = await loadingTask.promise;

      this.totalPages.set(pdf.numPages);

      let textAccumulator: string[] = [];
      for (let pageNumber = 1; pageNumber <= pdf.numPages; pageNumber++) {
        const page = await pdf.getPage(pageNumber);
        const content = await page.getTextContent();
        const textItems = content.items as Array<{ str?: string }>;
        const pageText = textItems
          .map(item => item.str ?? '')
          .join(' ')
          .replace(/\s+/g, ' ')
          .trim();

        if (pageText) {
          textAccumulator.push(pageText);
        }

        this.processedPages.set(pageNumber);
      }

      const finalText = textAccumulator.join('\n\n');
      this.extractedText.set(finalText || 'Nessun testo estratto dal documento.');
    } catch (error) {
      console.error('Errore durante la conversione PDF:', error);
      this.errorMessage.set('Non è stato possibile leggere il PDF. Verifica che il file non sia protetto o riprova più tardi.');
    } finally {
      this.isProcessing.set(false);
    }
  }

  clearSelection(): void {
    this.selectedFile.set(null);
    this.extractedText.set('');
    this.errorMessage.set('');
    this.processedPages.set(0);
    this.totalPages.set(0);
  }

  async copyExtractedText(): Promise<void> {
    if (!this.hasText() || typeof navigator === 'undefined' || !navigator.clipboard) {
      return;
    }

    try {
      await navigator.clipboard.writeText(this.extractedText());
    } catch (error) {
      console.warn('Impossibile copiare il testo negli appunti:', error);
    }
  }
}

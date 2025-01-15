import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import * as pdfjsLib from 'pdfjs-dist';
import { HeaderComponent } from "../header/header.component";

@Component({
  selector: 'app-pdf-to-txt-quiz',
  templateUrl: './pdf-to-txt-quiz.component.html',
  styleUrls: ['./pdf-to-txt-quiz.component.scss'],
  standalone: true,
  imports: [
    CommonModule,
    HeaderComponent
  ],
})
export class PdfToTxtComponent implements OnInit {
  uploadedFile: File | null = null;
  txtContent: string = '';

  ngOnInit(): void {
    pdfjsLib.GlobalWorkerOptions.workerSrc = 'pdfjs-worker/pdf.worker.min.mjs';
  }

  onFileSelected(event: Event) {
    const input = event.target as HTMLInputElement;
    if (input.files?.length) {
      this.uploadedFile = input.files[0];
      this.processPDF();
    }
  }

  async processPDF() {
    if (!this.uploadedFile) return;

    const fileReader = new FileReader();
    fileReader.onload = async (event) => {
      const typedArray = new Uint8Array(event.target?.result as ArrayBuffer);

      try {
        const pdfDoc = await pdfjsLib.getDocument(typedArray).promise;
        const numPages = pdfDoc.numPages;
        let extractedText = '';

        for (let pageIndex = 1; pageIndex <= numPages; pageIndex++) {
          const page = await pdfDoc.getPage(pageIndex);
          const textContent = await page.getTextContent();

          const pageText = textContent.items.map(item =>
            'str' in item ? item.str : ''
          ).join(' ');

          extractedText += pageText + '\n';
        }

        const cleanedText = this.cleanText(extractedText);
        const txtText = this.extractAndFormatJSON(cleanedText);
        this.downloadTxtFile(txtText);
      } catch (error) {
        console.error('Errore nell’elaborazione del PDF:', error);
      }
    };
    fileReader.readAsArrayBuffer(this.uploadedFile);
  }

  /**
   * Elimina righe indesiderate e pulisce il testo
   */
  cleanText(text: string): string {
    return text.replace(/DO NOT PAY FOR THIS DOCUMENT.*?NON PAGARE PER QUESTO DOCUMENTO/g, '');
  } 
  
  extractAndFormatJSON(text: string): string {
    // Rimuove spazi multipli e normalizza il testo
    text = text.replace(/\s{2,}/g, ' ').trim();

    console.log('text', text)
    // Regex migliorato per separare domande e correggere segmentazioni incomplete
    const regex = /(\d+\..*?(?:[A-D]\..*?)+?(?:Answe?r ?: [A-D]).*?Section ?: .+?)(?=\d+\.\s|$)/gs;
    const matches = text.match(regex);

    if (!matches) {
      console.log('Nessun Txt trovato');
      return JSON.stringify([]);
    }

    // Converte ogni match in un oggetto JSON
    const questions: any[] = [];
    for (let i = 0; i < matches.length; i++) {
      const currentMatch = matches[i];
      const nextMatch = matches[i + 1] || '';

      // Controlla se la domanda corrente è incompleta
      if (this.isIncompleteQuestion(currentMatch, nextMatch)) {
        matches[i + 1] = this.mergeIncompleteQuestion(currentMatch, nextMatch);
        continue;
      }

      // Aggiungi la domanda completa
      questions.push(this.parseQuestion(currentMatch));
    }

    return JSON.stringify(questions, null, 2);
  }

  /**
   * Verifica se una domanda è incompleta
   */
  isIncompleteQuestion(current: string, next: string): boolean {
    return !/Answer: [A-D]/.test(current) && next.startsWith('Section:');
  }

  /**
   * Unisce una domanda incompleta con la successiva
   */
  mergeIncompleteQuestion(current: string, next: string): string {
    return current.trim() + ' ' + next.trim();
  }

  /**
   * Parsea una domanda completa in un oggetto JSON
   */
  parseQuestion(questionText: string): object {
    const questionRegex = /^(\d+\..*?):/;
    const optionsRegex = /([A-D]\..*?)(?=\s[A-D]\.|Answer:)/g;
    const answerRegex = /Answer: ([A-D])/;
    const sectionRegex = /Section: (.+)$/;

    const questionMatch = questionText.match(questionRegex);
    const optionsMatch = questionText.match(optionsRegex);
    const answerMatch = questionText.match(answerRegex);
    const sectionMatch = questionText.match(sectionRegex);

    return {
      question: questionMatch ? questionMatch[1].trim() : '',
      options: optionsMatch ? optionsMatch.map(opt => opt.trim()) : [],
      answer: answerMatch ? answerMatch[1].trim() : '',
      section: sectionMatch ? sectionMatch[1].trim() : ''
    };
  }

  downloadTxtFile(txtContent: string) {
    const blob = new Blob([txtContent], { type: 'text/plain' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = this.uploadedFile?.name ? this.uploadedFile.name.replace('.pdf', '.json') : 'default.json';
    link.click();
    URL.revokeObjectURL(link.href);
  }
}
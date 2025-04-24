import { RouterOutlet } from '@angular/router';
import { Component } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { ReactiveFormsModule, FormBuilder, FormGroup, Validators } from '@angular/forms';
import { CommonModule } from '@angular/common';
import { environment } from '../environments/environment';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, RouterOutlet],
  templateUrl: './app.component.html',
})
export class AppComponent {
  form: FormGroup;
  result: number | null = null;
  error: string | null = null;

  constructor(private fb: FormBuilder, private http: HttpClient) {
    this.form = this.fb.group({
      numbers: ['', [Validators.required]],
      windowSize: [3, [Validators.required, Validators.min(1)]],
    });
  }

  onSubmit() {
    this.result = null;
    this.error = null;

    const numbersArray = this.form.value.numbers
      .split(',')
      .map((n: string) => n.trim())
      .filter((n: string) => n !== '')
      .map(Number);

    // const params = new HttpParams()
    //   .set('windowSize', this.form.value.windowSize)
    //   .set('numbers', numbersArray.join('&numbers='));
    const params = new HttpParams()
      .set('windowSize', this.form.value.windowSize)
      .set('numbers', numbersArray.join(','));

    this.http.get<{ maxSum: number }>(
      `${environment.apiBaseUrl}/api/sliding-window`, { params }
    ).subscribe({
      next: (res) => this.result = res.maxSum,
      error: (err) => this.error = err.message,
    });
  }
}

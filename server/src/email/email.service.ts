import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Resend } from 'resend';
import { welcomeTemplate } from './templates/welcome.template';
import { resetPasswordTemplate } from './templates/reset-password.template';
import { verifyEmailTemplate } from './templates/verify-email.template';

// Every send is best-effort: a Resend outage must never surface as a 500 on
// register/forgot-password, so failures are only logged, never thrown.
@Injectable()
export class EmailService {
  private readonly logger = new Logger(EmailService.name);
  private readonly resend: Resend;
  private readonly from: string;

  constructor(config: ConfigService) {
    this.resend = new Resend(config.getOrThrow<string>('RESEND_API_KEY'));
    this.from = config.getOrThrow<string>('EMAIL_FROM');
  }

  async sendWelcomeEmail(to: string, firstName: string | null): Promise<void> {
    const { subject, html, text } = welcomeTemplate(firstName);
    await this.send(to, subject, html, text);
  }

  async sendPasswordResetEmail(to: string, resetUrl: string): Promise<void> {
    const { subject, html, text } = resetPasswordTemplate(resetUrl);
    await this.send(to, subject, html, text);
  }

  async sendVerificationCodeEmail(to: string, code: string): Promise<void> {
    const { subject, html, text } = verifyEmailTemplate(code);
    await this.send(to, subject, html, text);
  }

  private async send(
    to: string,
    subject: string,
    html: string,
    text: string,
  ): Promise<void> {
    try {
      const { error } = await this.resend.emails.send({
        from: this.from,
        to,
        subject,
        html,
        text,
      });
      if (error) this.logger.error(`Resend rejected email to ${to}: ${error.message}`);
    } catch (err: any) {
      this.logger.error(`Failed to send email to ${to}: ${err.message}`);
    }
  }
}

interface EmailContent {
  subject: string;
  html: string;
  text: string;
}

// the code leads the subject so it shows in the notification/inbox preview;
// the iOS keyboard also picks it up from Mail for the .oneTimeCode field
export function verifyEmailTemplate(code: string): EmailContent {
  return {
    subject: `${code} é seu código do SoTreina`,
    text: `Use este código para confirmar seu email no SoTreina:\n\n${code}\n\nEle vale por 10 minutos. Se você não criou uma conta no SoTreina, pode ignorar este email.`,
    html: `
      <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; max-width: 480px; margin: 0 auto; color: #1a1a1a;">
        <p style="font-size: 15px; line-height: 1.6;">
          Use este código para confirmar seu email no <strong>SoTreina</strong>:
        </p>
        <p style="margin: 24px 0; font-family: ui-monospace, 'SF Mono', Menlo, monospace; font-size: 32px; font-weight: 600; letter-spacing: 6px;">
          ${code}
        </p>
        <p style="font-size: 13px; line-height: 1.6; color: #666;">
          Ele vale por 10 minutos. Se você não criou uma conta no SoTreina, pode ignorar este email.
        </p>
      </div>
    `,
  };
}

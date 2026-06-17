const nodemailer = require('nodemailer');

class EmailService {
  static getTransporter() {
    return nodemailer.createTransport({
      host: process.env.SMTP_HOST || 'smtp.gmail.com',
      port: parseInt(process.env.SMTP_PORT || '587'),
      secure: process.env.SMTP_PORT === '465', // true for 465, false for other ports
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
      },
    });
  }

  static async sendOtpEmail(toEmail, otp, userName = 'Gym Member') {
    const transporter = this.getTransporter();
    
    // HTML email template with premium styling (dark themed, neon green highlights)
    const htmlContent = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Reset Your Gym Trainer Password</title>
      <style>
        body {
          font-family: 'Montserrat', 'Helvetica Neue', Helvetica, Arial, sans-serif;
          background-color: #0A0A0F;
          color: #E2E2E9;
          margin: 0;
          padding: 0;
          -webkit-font-smoothing: antialiased;
        }
        .container {
          max-width: 600px;
          margin: 40px auto;
          background: linear-gradient(135deg, #16121E 0%, #0D0914 100%);
          border: 1px solid #2A2438;
          border-radius: 20px;
          overflow: hidden;
          box-shadow: 0 10px 30px rgba(0, 0, 0, 0.5);
        }
        .header {
          padding: 40px 0 20px 0;
          text-align: center;
          background: rgba(26, 3, 48, 0.4);
          border-bottom: 1px solid rgba(203, 255, 71, 0.1);
        }
        .logo {
          font-size: 24px;
          font-weight: 800;
          letter-spacing: 1px;
          color: #CBFF47;
          text-transform: uppercase;
        }
        .content {
          padding: 40px 30px;
          text-align: center;
        }
        h1 {
          font-size: 22px;
          font-weight: 700;
          color: #FFFFFF;
          margin-bottom: 10px;
        }
        p {
          font-size: 14px;
          line-height: 1.6;
          color: #A09BAA;
          margin: 0 0 24px 0;
        }
        .otp-container {
          background: rgba(203, 255, 71, 0.05);
          border: 2px dashed rgba(203, 255, 71, 0.3);
          border-radius: 12px;
          padding: 24px;
          margin: 30px 0;
          display: inline-block;
          letter-spacing: 6px;
        }
        .otp-code {
          font-size: 36px;
          font-weight: 800;
          color: #CBFF47;
          font-family: monospace;
          margin: 0;
          padding-left: 6px; /* Offset the letter-spacing on the last digit */
        }
        .expiry {
          font-size: 12px;
          color: #FF5C5C;
          font-weight: 600;
          margin-top: 10px;
        }
        .footer {
          padding: 30px;
          background: rgba(0, 0, 0, 0.2);
          border-top: 1px solid #2A2438;
          text-align: center;
          font-size: 11px;
          color: #625E6A;
        }
        .footer a {
          color: #CBFF47;
          text-decoration: none;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <div class="logo">💪 GYM TRAINER</div>
        </div>
        <div class="content">
          <h1>Password Reset Request</h1>
          <p>Hello ${userName},</p>
          <p>We received a request to reset your password. Use the verification code below to proceed with setting your new password:</p>
          
          <div class="otp-container">
            <div class="otp-code">${otp}</div>
            <div class="expiry">Expires in 5 minutes</div>
          </div>
          
          <p>If you did not request this, please ignore this email or contact support if you have security concerns.</p>
        </div>
        <div class="footer">
          &copy; 2026 Gym Trainer App. All rights reserved.<br>
          If you need help, contact our <a href="mailto:support@gymtrainer.com">Support Team</a>
        </div>
      </div>
    </body>
    </html>
    `;

    const mailOptions = {
      from: `"Gym Trainer App" <${process.env.SMTP_USER}>`,
      to: toEmail,
      subject: '🔑 Password Reset OTP Code - Gym Trainer',
      html: htmlContent,
    };

    return transporter.sendMail(mailOptions);
  }
}

module.exports = EmailService;

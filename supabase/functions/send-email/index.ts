import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Resend API configuration
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')
const FROM_EMAIL = Deno.env.get('FROM_EMAIL') || 'noreply@fixmycity.app'

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Create Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    )

    // Get request body
    const { email, subject, message, otp } = await req.json()

    if (!email || !subject || !message || !otp) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Send email using Resend API
    let emailResult
    
    if (RESEND_API_KEY) {
      try {
        const emailResponse = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${RESEND_API_KEY}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            from: FROM_EMAIL,
            to: [email],
            subject: subject,
            html: `
              <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
                <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; border-radius: 10px; text-align: center; margin-bottom: 20px;">
                  <h1 style="color: white; margin: 0; font-size: 28px;">FixmyCity</h1>
                  <p style="color: white; margin: 10px 0 0 0; opacity: 0.9;">Email Verification</p>
                </div>
                
                <div style="background: #f8f9fa; padding: 30px; border-radius: 10px; text-align: center;">
                  <h2 style="color: #333; margin-bottom: 20px;">Your Verification Code</h2>
                  <div style="background: white; padding: 20px; border-radius: 8px; border: 2px dashed #667eea; margin: 20px 0;">
                    <span style="font-size: 32px; font-weight: bold; color: #667eea; letter-spacing: 8px;">${otp}</span>
                  </div>
                  <p style="color: #666; margin: 20px 0;">Enter this code in the app to verify your email address.</p>
                  <p style="color: #999; font-size: 14px;">This code will expire in 5 minutes.</p>
                </div>
                
                <div style="text-align: center; margin-top: 20px; padding: 20px; color: #999; font-size: 12px;">
                  <p>If you didn't request this code, please ignore this email.</p>
                  <p>© 2024 FixmyCity. All rights reserved.</p>
                </div>
              </div>
            `,
          }),
        })

        if (!emailResponse.ok) {
          const errorData = await emailResponse.text()
          throw new Error(`Resend API error: ${emailResponse.status} - ${errorData}`)
        }

        emailResult = await emailResponse.json()
        console.log('Email sent successfully via Resend:', emailResult.id)
        
      } catch (emailError) {
        console.error('Error sending email via Resend:', emailError)
        throw emailError
      }
    } else {
      // Fallback: Log email details if no API key is configured
      console.log(`📧 RESEND_API_KEY not configured - Email would be sent to: ${email}`)
      console.log(`📧 Subject: ${subject}`)
      console.log(`📧 OTP: ${otp}`)
      emailResult = { id: `fallback_${Date.now()}` }
    }

    // Store email record in Supabase for tracking
    try {
      const { error: insertError } = await supabaseClient
        .from('email_logs')
        .insert({
          email,
          subject,
          message,
          otp,
          status: RESEND_API_KEY ? 'sent' : 'logged',
          message_id: emailResult.id,
          created_at: new Date().toISOString(),
        })

      if (insertError) {
        console.error('Error storing email log:', insertError)
      }
    } catch (dbError) {
      console.log('Email logs table may not exist, continuing without logging')
    }

    // Return success response
    return new Response(
      JSON.stringify({ 
        success: true, 
        message_id: emailResult.id,
        status: 'sent',
        message: RESEND_API_KEY ? 'Email sent successfully' : 'Email logged (configure RESEND_API_KEY for actual sending)'
      }),
      { 
        status: 200, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )

  } catch (error) {
    console.error('Error sending email:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: error.message }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})


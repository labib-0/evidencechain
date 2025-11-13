import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const supabase = createClient(supabaseUrl!, supabaseKey!);

    const { file_path, case_id, metadata } = await req.json();

    // Download file from storage
    const { data: fileData, error: downloadError } = await supabase.storage
      .from("evidence")
      .download(file_path);

    if (downloadError) throw downloadError;

    // Calculate SHA-256 hash
    const buffer = await fileData.arrayBuffer();
    const hashBuffer = await crypto.subtle.digest("SHA-256", buffer);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    const hashHex = hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");

    // Get previous evidence hash
    const { data: lastEvidence } = await supabase
      .from("evidence")
      .select("current_hash")
      .eq("case_id", case_id)
      .order("created_at", { ascending: false })
      .limit(1)
      .single();

    // Generate QR code data
    const qrData = JSON.stringify({
      evidence_id: metadata.evidence_id,
      hash: hashHex,
      timestamp: new Date().toISOString(),
    });

    // Insert evidence record
    const { data: evidence, error: insertError } = await supabase
      .from("evidence")
      .insert({
        case_id,
        file_name: metadata.file_name,
        file_size: metadata.file_size,
        mime_type: metadata.mime_type,
        current_hash: hashHex,
        previous_hash: lastEvidence?.current_hash || null,
        evidence_name: metadata.evidence_name,
        description: metadata.description,
        evidence_type: metadata.evidence_type,
        storage_location: file_path,
        status: "Valid",
        verification_status: "Verified",
        qr_code_data: qrData,
        qr_code_gen_date: new Date().toISOString(),
      })
      .select()
      .single();

    if (insertError) throw insertError;

    return new Response(
      JSON.stringify({
        success: true,
        evidence_id: evidence.id,
        hash: hashHex,
        qr_code: qrData,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      }
    );
  }
});

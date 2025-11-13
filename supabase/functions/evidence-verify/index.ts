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

    const { evidence_id } = await req.json();

    // Get evidence from database
    const { data: evidence, error: fetchError } = await supabase
      .from("evidence")
      .select("*")
      .eq("id", evidence_id)
      .single();

    if (fetchError) throw fetchError;

    // Download file from storage
    const { data: fileData, error: downloadError } = await supabase.storage
      .from("evidence")
      .download(evidence.storage_location);

    if (downloadError) throw downloadError;

    // Recalculate SHA-256 hash
    const buffer = await fileData.arrayBuffer();
    const hashBuffer = await crypto.subtle.digest("SHA-256", buffer);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    const newHash = hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");

    // Compare hashes
    const isValid = newHash === evidence.current_hash;

    if (!isValid) {
      // Update evidence status to Compromised
      await supabase
        .from("evidence")
        .update({
          status: "Compromised",
          verification_status: "Failed",
        })
        .eq("id", evidence_id);

      // Log tampering
      await supabase.from("audit_log").insert({
        evidence_id,
        action: "Tampering",
        result: "Success",
        timestamp: new Date().toISOString(),
      });
    }

    return new Response(
      JSON.stringify({
        success: true,
        is_valid: isValid,
        current_hash: evidence.current_hash,
        calculated_hash: newHash,
        status: isValid ? "Valid" : "Tampering Detected",
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

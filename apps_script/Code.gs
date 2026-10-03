/**
 * Market Analysis - Google Apps Script Backend & Supabase Sync
 * 
 * Supports 100% separate sheets for:
 * - MarketP: Production Environment (Sheets: MarketP_Purchases, MarketP_Sales, MarketP_Farmers, MarketP_Factories, MarketP_Workers)
 * - MarketT: Test Environment (Sheets: MarketT_Purchases, MarketT_Sales, MarketT_Farmers, MarketT_Factories, MarketT_Workers)
 * 
 * Features:
 * 1. Automatic "Market Analysis" menu in Google Sheets with one-click Sync from Supabase!
 * 2. Web App API endpoint (doGet, doPost) for Flutter mobile/web app export and sync.
 * 3. Can run on a scheduled trigger (e.g. every hour or daily) to automatically pull Supabase data into Google Sheets.
 * 
 * SETUP INSTRUCTIONS:
 * 1. Open Google Sheets (https://sheets.new).
 * 2. Click "Extensions" -> "Apps Script".
 * 3. Replace all code in Code.gs with this file.
 * 4. Enter your Supabase URL & Anon Key in the CONFIG section below.
 * 5. Click "Run" -> "onOpen" to create the custom menu immediately.
 * 6. (Optional) Deploy as Web App if you want the Flutter app to post directly to Google Sheets:
 *    - Click "Deploy" -> "New deployment" -> Select "Web app"
 *    - Execute as: "Me", Who has access: "Anyone"
 *    - Copy Web App URL into your Flutter app's .env file.
 */

// ====================================================================
// CONFIGURATION (Enter your Supabase credentials here)
// ====================================================================
const CONFIG = {
  SUPABASE_URL: "https://ttrgrhrpvxyrsvkjqhmk.supabase.co",
  SUPABASE_ANON_KEY: "sb_publishable_jGN32nGNcCMBoUtuq6EyJg_24Kxi3On",
};

// ====================================================================
// 1. GOOGLE SHEETS CUSTOM MENU (Runs when spreadsheet is opened)
// ====================================================================
function onOpen() {
  SpreadsheetApp.getUi()
    .createMenu("📊 Market Analysis")
    .addItem("🔄 Sync Production (MarketP) from Supabase", "syncProductionFromSupabase")
    .addItem("🧪 Sync Test (MarketT) from Supabase", "syncTestFromSupabase")
    .addSeparator()
    .addItem("🔄 Sync ALL (MarketP & MarketT)", "syncAllFromSupabase")
    .addToUi();
}

// Menu Action: Sync MarketP (Production)
function syncProductionFromSupabase() {
  const count = syncEnvironment("p", "MarketP");
  SpreadsheetApp.getActiveSpreadsheet().toast(
    "MarketP (Production) sync completed! Synced " + count + " records.",
    "Sync Success",
    5
  );
}

// Menu Action: Sync MarketT (Test)
function syncTestFromSupabase() {
  const count = syncEnvironment("t", "MarketT");
  SpreadsheetApp.getActiveSpreadsheet().toast(
    "MarketT (Test) sync completed! Synced " + count + " records.",
    "Sync Success",
    5
  );
}

// Menu Action: Sync Both
function syncAllFromSupabase() {
  const pCount = syncEnvironment("p", "MarketP");
  const tCount = syncEnvironment("t", "MarketT");
  SpreadsheetApp.getActiveSpreadsheet().toast(
    "All data synced! MarketP: " + pCount + " rows, MarketT: " + tCount + " rows.",
    "Complete Sync",
    6
  );
}

// Core sync engine pulling from Supabase REST API
function syncEnvironment(prefix, envName) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let totalRows = 0;

  // 1. Sync Purchases
  const purchases = fetchFromSupabase(prefix + "_purchases");
  const purchaseHeaders = [
    "ID", "Crop Name", "Farmer Name", "Farmer Phone", "Farmer Address",
    "Farmer Details", "Gross Quantity", "Suits (Kg)", "Net Quantity", "Unit", "Price Per Unit", "Total Amount", "Advance Paid", "Net Payable", "Date", "Created At"
  ];
  const purchaseRows = purchases.map(p => [
    p.id || "", p.crop_name || "", p.farmer_name || "", p.farmer_phone || "",
    p.farmer_address || "", p.farmer_details || "", p.quantity || 0, p.suits_kg || 0,
    p.net_quantity != null ? p.net_quantity : p.quantity || 0, p.unit || "Quintal",
    p.price_per_unit || 0, p.total_amount || 0, p.advance_paid || 0,
    p.net_payable != null ? p.net_payable : p.total_amount || 0, p.date || "", p.created_at || ""
  ]);
  writeToSheet(ss, envName + "_Purchases", purchaseHeaders, purchaseRows);
  totalRows += purchaseRows.length;

  // 2. Sync Sales
  const sales = fetchFromSupabase(prefix + "_sales");
  const saleHeaders = [
    "ID", "Crop Name", "Factory Name", "Factory Contact", "Factory Address",
    "Quantity", "Unit", "Sold Amount", "Price Per Unit", "Date", "Created At"
  ];
  const saleRows = sales.map(s => [
    s.id || "", s.crop_name || "", s.factory_name || "", s.factory_contact || "",
    s.factory_address || "", s.quantity || 0, s.unit || "Quintal",
    s.sold_amount || 0, s.price_per_unit || 0, s.date || "", s.created_at || ""
  ]);
  writeToSheet(ss, envName + "_Sales", saleHeaders, saleRows);
  totalRows += saleRows.length;

  // 3. Sync Farmers
  const farmers = fetchFromSupabase(prefix + "_farmers");
  const farmerHeaders = ["ID", "Farmer Name", "Phone", "Address", "Notes", "Created At"];
  const farmerRows = farmers.map(f => [
    f.id || "", f.name || "", f.phone || "", f.address || "", f.notes || "", f.created_at || ""
  ]);
  writeToSheet(ss, envName + "_Farmers", farmerHeaders, farmerRows);
  totalRows += farmerRows.length;

  // 4. Sync Factories
  const factories = fetchFromSupabase(prefix + "_factories");
  const factoryHeaders = ["ID", "Factory Name", "Contact", "Address", "Notes", "Created At"];
  const factoryRows = factories.map(f => [
    f.id || "", f.name || "", f.contact || "", f.address || "", f.notes || "", f.created_at || ""
  ]);
  writeToSheet(ss, envName + "_Factories", factoryHeaders, factoryRows);
  totalRows += factoryRows.length;

  // 5. Sync Workers
  const workers = fetchFromSupabase(prefix + "_workers");
  const workerHeaders = ["ID", "Worker Name", "Phone", "Role", "Address", "Daily Wage", "Present Today", "Joined Date", "Notes", "Created At"];
  const workerRows = workers.map(w => [
    w.id || "", w.name || "", w.phone || "", w.role || "", w.address || "",
    w.daily_wage || 0, w.is_present_today ? "Yes" : "No", w.joined_date || "", w.notes || "", w.created_at || ""
  ]);
  writeToSheet(ss, envName + "_Workers", workerHeaders, workerRows);
  totalRows += workerRows.length;

  // 6. Sync Other Expenditures
  const expenditures = fetchFromSupabase(prefix + "_expenditures");
  const expenditureHeaders = ["ID", "Title / Purpose", "Category", "Amount", "Paid To", "Payment Mode", "Date", "Notes", "Created At"];
  const expenditureRows = expenditures.map(e => [
    e.id || "", e.title || "", e.category || "", e.amount || 0,
    e.paid_to || "", e.payment_mode || "Cash", e.date || "", e.notes || "", e.created_at || ""
  ]);
  writeToSheet(ss, envName + "_Expenditures", expenditureHeaders, expenditureRows);
  totalRows += expenditureRows.length;

  return totalRows;
}

// Fetch records from Supabase REST API
function fetchFromSupabase(tableName) {
  if (!CONFIG.SUPABASE_URL || !CONFIG.SUPABASE_ANON_KEY) return [];
  const endpoint = CONFIG.SUPABASE_URL.replace(/\/+$/, "") + "/rest/v1/" + tableName + "?select=*";
  try {
    const response = UrlFetchApp.fetch(endpoint, {
      method: "GET",
      headers: {
        "apikey": CONFIG.SUPABASE_ANON_KEY,
        "Authorization": "Bearer " + CONFIG.SUPABASE_ANON_KEY,
        "Content-Type": "application/json"
      },
      muteHttpExceptions: true
    });
    if (response.getResponseCode() === 200) {
      return JSON.parse(response.getContentText());
    }
  } catch (err) {
    Logger.log("Error fetching " + tableName + ": " + err);
  }
  return [];
}

// Writes headers and rows with clean styling
function writeToSheet(ss, sheetName, headers, rows) {
  let sheet = ss.getSheetByName(sheetName);
  if (!sheet) {
    sheet = ss.insertSheet(sheetName);
  } else {
    sheet.clear();
  }

  // Write headers
  sheet.appendRow(headers);
  const headerRange = sheet.getRange(1, 1, 1, headers.length);
  headerRange.setFontWeight("bold");
  headerRange.setBackground(sheetName.startsWith("MarketP") ? "#E8F5E9" : "#FFF3E0");
  headerRange.setFontColor(sheetName.startsWith("MarketP") ? "#1B5E20" : "#E65100");

  if (rows.length > 0) {
    sheet.getRange(2, 1, rows.length, headers.length).setValues(rows);
  }
  sheet.autoResizeColumns(1, headers.length);
}

// ====================================================================
// 2. HTTP ENDPOINTS (doGet & doPost for Web App)
// ====================================================================
function doGet(e) {
  try {
    const action = e.parameter.action;
    const env = e.parameter.env || "MarketP";
    const prefix = env === "MarketT" ? "t" : "p";

    if (action === "sync") {
      const count = syncEnvironment(prefix, env);
      return jsonResponse({ status: "success", count: count, env: env });
    }

    if (action === "ping") {
      return jsonResponse({ status: "ok", app: "Market Analysis Backend" });
    }

    return jsonResponse({ status: "error", message: "Unknown action" }, 400);
  } catch (err) {
    return jsonResponse({ status: "error", message: err.toString() }, 500);
  }
}

function doPost(e) {
  try {
    const contents = JSON.parse(e.postData.contents);
    const action = contents.action;
    const env = contents.env || "MarketP";
    const prefix = env === "MarketT" ? "t" : "p";
    const ss = SpreadsheetApp.getActiveSpreadsheet();

    if (action === "syncAll") {
      const count = syncEnvironment(prefix, env);
      return jsonResponse({ status: "success", count: count, env: env });
    }

    if (action === "addPurchase") {
      const data = contents.data;
      const sheetName = env + "_Purchases";
      let sheet = ss.getSheetByName(sheetName);
      if (!sheet) {
        syncEnvironment(prefix, env);
        sheet = ss.getSheetByName(sheetName);
      }
      sheet.appendRow([
        data.id, data.cropName, data.farmerName, data.farmerPhone || "",
        data.farmerAddress || "", data.farmerDetails || "", data.quantity,
        data.suitsKg || 0, data.netQuantity != null ? data.netQuantity : data.quantity,
        data.unit, data.pricePerUnit, data.totalAmount,
        data.advancePaid || 0, data.netPayable != null ? data.netPayable : data.totalAmount,
        data.date, new Date().toISOString()
      ]);
      return jsonResponse({ status: "success" });
    }

    if (action === "addSale") {
      const data = contents.data;
      const sheetName = env + "_Sales";
      let sheet = ss.getSheetByName(sheetName);
      if (!sheet) {
        syncEnvironment(prefix, env);
        sheet = ss.getSheetByName(sheetName);
      }
      sheet.appendRow([
        data.id, data.cropName, data.factoryName, data.factoryContact || "",
        data.factoryAddress || "", data.quantity, data.unit, data.soldAmount,
        data.pricePerUnit, data.date, new Date().toISOString()
      ]);
      return jsonResponse({ status: "success" });
    }

    if (action === "addExpenditure") {
      const data = contents.data;
      const sheetName = env + "_Expenditures";
      let sheet = ss.getSheetByName(sheetName);
      if (!sheet) {
        syncEnvironment(prefix, env);
        sheet = ss.getSheetByName(sheetName);
      }
      sheet.appendRow([
        data.id, data.title, data.category, data.amount,
        data.paidTo || "", data.paymentMode || "Cash", data.date, data.notes || "", new Date().toISOString()
      ]);
      return jsonResponse({ status: "success" });
    }

    return jsonResponse({ status: "error", message: "Unknown action" }, 400);
  } catch (err) {
    return jsonResponse({ status: "error", message: err.toString() }, 500);
  }
}

function jsonResponse(data, code) {
  return ContentService.createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}

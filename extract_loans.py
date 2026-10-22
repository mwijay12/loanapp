import re
import json

def extract_loans(file_path):
    with open(file_path, 'r') as f:
        content = f.read()

    # Find the loans list
    loans_match = re.search(r'static final List<LoanItem> loans = \[(.*?)\];', content, re.DOTALL)
    if not loans_match:
        return []

    loans_text = loans_match.group(1)
    
    # Split by LoanItem(
    items = re.split(r'LoanItem\(', loans_text)
    extracted = []
    
    for item in items[1:]:
        # Extract fields using regex
        data = {}
        
        # Map Dart id to loan_no
        id_m = re.search(r"id:\s*'([^']+)'", item)
        if id_m: data['loan_no'] = id_m.group(1)
        
        name_m = re.search(r"name:\s*'([^']+)'", item)
        if name_m: data['borrower_name'] = name_m.group(1)
        
        item_m = re.search(r"item:\s*'([^']+)'", item)
        if item_m: data['item_name'] = item_m.group(1)
        
        amount_m = re.search(r"amount:\s*(\d+)", item)
        if amount_m: data['amount'] = int(amount_m.group(1))
        
        paid_m = re.search(r"paid:\s*(\d+)", item)
        if paid_m: data['paid_percent'] = int(paid_m.group(1))
        
        due_m = re.search(r"due:\s*'([^']+)'", item)
        if due_m: data['due_info'] = due_m.group(1)
        
        status_m = re.search(r"status:\s*'([^']+)'", item)
        if status_m: data['status'] = status_m.group(1)
        
        phone_m = re.search(r"phone:\s*'([^']+)'", item)
        if phone_m: data['phone'] = phone_m.group(1)
        
        nida_m = re.search(r"nida:\s*'([^']+)'", item)
        if nida_m: data['nida'] = nida_m.group(1)
        
        loc_m = re.search(r"location:\s*'([^']+)'", item)
        if loc_m: data['location'] = loc_m.group(1)
        
        biz_m = re.search(r"businessAddress:\s*'([^']+)'", item)
        if biz_m: data['business_address'] = biz_m.group(1)
        
        imei_m = re.search(r"imei:\s*'([^']+)'", item)
        if imei_m: data['imei'] = imei_m.group(1)
        
        gname_m = re.search(r"guarantorName:\s*'([^']+)'", item)
        if gname_m: data['guarantor_name'] = gname_m.group(1)
        
        gphone_m = re.search(r"guarantorPhone:\s*'([^']+)'", item)
        if gphone_m: data['guarantor_phone'] = gphone_m.group(1)
        
        grel_m = re.search(r"guarantorRelation:\s*'([^']+)'", item)
        if grel_m: data['guarantor_relation'] = grel_m.group(1)
        
        dep_m = re.search(r"totalDeposit:\s*(\d+)", item)
        if dep_m: data['deposit'] = int(dep_m.group(1))
        
        inst_m = re.search(r"weeklyInstallment:\s*(\d+)", item)
        if inst_m: data['weekly_installment'] = int(inst_m.group(1))
        
        weeks_m = re.search(r"installmentWeeks:\s*(\d+)", item)
        if weeks_m: data['installment_weeks'] = int(weeks_m.group(1))

        # Default values for missing columns in some records
        data['avatar_asset'] = 'assets/images/avatar_loan.png'
        
        extracted.append(data)
        
    return extracted

loans = extract_loans('frontend/lib/core/data/mock_lims_data.dart')
# Assign Mbagala Branch ID
branch_id = "c4a651ae-88c5-4557-994f-6fd179941027"
for l in loans:
    l['branch_id'] = branch_id

with open('loans.json', 'w') as f:
    json.dump(loans, f, indent=2)

print(f"Extracted {len(loans)} loans.")

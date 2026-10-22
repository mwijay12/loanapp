import json

with open('products.json', 'r') as f:
    products = json.load(f)

# Columns to remove because they are likely missing or causing issues
# Based on the error PGRST204 for 'on_offer'
remove_cols = ['on_offer', 'offer_note', 'is_favorite', 'sold_today', 'on_loan']

cleaned_products = []
for p in products:
    cleaned_p = {k: v for k, v in p.items() if k not in remove_cols}
    # Ensure all items have the same keys for PostgREST bulk insert
    cleaned_products.append(cleaned_p)

with open('products_cleaned.json', 'w') as f:
    json.dump(cleaned_products, f, indent=2)

print(f"Cleaned {len(cleaned_products)} products. Saved to products_cleaned.json")

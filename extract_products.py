
import re
import json

content = open('frontend/lib/core/data/mock_lims_data.dart').read()

# Find the start of the products list
start_match = re.search(r'static final List<ProductItem> products = \[', content)
start_index = start_match.end()

# Extract the block containing products
# We look for the closing bracket of the list
depth = 1
end_index = start_index
while depth > 0 and end_index < len(content):
    if content[end_index] == '[':
        depth += 1
    elif content[end_index] == ']':
        depth -= 1
    end_index += 1

products_block = content[start_index:end_index-1]

# Now split by ProductItem(
items = re.split(r'ProductItem\(', products_block)[1:]

products = []

def parse_val(item, key, is_int=False, is_bool=False, default=None):
    pattern = rf"{key}:\s*(.*?)[,\n]"
    match = re.search(pattern, item, re.DOTALL)
    if not match:
        return default
    val = match.group(1).strip()
    if val.startswith("'") or val.startswith('"'):
        return val[1:-1]
    if is_int:
        try:
            return int(re.search(r'(\d+)', val).group(1))
        except:
            return 0
    if is_bool:
        return val == 'true'
    return val

all_keys = [
    'id', 'name', 'brand', 'variant', 'sku', 'price', 'stock', 'min_stock',
    'category', 'gradient_start', 'gradient_end', 'status', 'sold_today',
    'on_loan', 'is_favorite', 'on_offer', 'image_asset', 'image_url'
]

for item in items:
    p = {}
    p['id'] = parse_val(item, 'id', is_int=True)
    p['name'] = parse_val(item, 'name')
    p['brand'] = parse_val(item, 'brand')
    p['variant'] = parse_val(item, 'variant')
    p['sku'] = parse_val(item, 'sku')
    p['price'] = parse_val(item, 'price', is_int=True)
    p['stock'] = parse_val(item, 'stock', is_int=True)
    p['min_stock'] = parse_val(item, 'min', is_int=True)
    p['category'] = parse_val(item, 'cat')
    
    grad_match = re.search(r'grad:\s*const\s*\[(.*?)\]', item, re.DOTALL)
    if grad_match:
        colors = re.findall(r'Color\(0xFF([0-9A-F]{6})\)', grad_match.group(1))
        if len(colors) >= 2:
            p['gradient_start'] = f'#{colors[0]}'
            p['gradient_end'] = f'#{colors[1]}'
    else:
        p['gradient_start'] = None
        p['gradient_end'] = None
    
    p['status'] = parse_val(item, 'status')
    p['sold_today'] = parse_val(item, 'soldToday', is_int=True)
    p['on_loan'] = parse_val(item, 'onLoan', is_int=True)
    p['is_favorite'] = parse_val(item, 'fav', is_bool=True, default=False)
    p['on_offer'] = parse_val(item, 'onOffer', is_bool=True, default=False)
    p['image_asset'] = parse_val(item, 'imageAsset')
    p['image_url'] = parse_val(item, 'imageUrl')

    
    # Ensure all keys are present
    full_p = {k: p.get(k) for k in all_keys}
    products.append(full_p)

print(json.dumps(products, indent=2))

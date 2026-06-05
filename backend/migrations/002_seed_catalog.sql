-- DHAV: Seed 50 catalog items into PostgreSQL
-- Run in: Supabase Dashboard → SQL Editor → New Query → Run

INSERT INTO catalog_items (id, name, name_hindi, name_marathi, category, unit, price, image_url, is_active, created_at)
VALUES

-- Grains
(gen_random_uuid()::text, 'Basmati Rice',        'बासमती चावल',         'बासमती तांदूळ',        'Grains',        '1 kg',       90,  '', true, 0),
(gen_random_uuid()::text, 'Toor Dal',            'तूर दाल',             'तूर डाळ',              'Grains',        '500 g',      65,  '', true, 0),
(gen_random_uuid()::text, 'Chana Dal',           'चना दाल',             'चणा डाळ',              'Grains',        '500 g',      60,  '', true, 0),
(gen_random_uuid()::text, 'Wheat Flour (Atta)',  'गेहूं का आटा',        'गव्हाचे पीठ',          'Grains',        '1 kg',       45,  '', true, 0),
(gen_random_uuid()::text, 'Poha',                'पोहा',                'पोहे',                 'Grains',        '500 g',      30,  '', true, 0),
(gen_random_uuid()::text, 'Sooji (Semolina)',    'सूजी',               'रवा',                  'Grains',        '500 g',      28,  '', true, 0),
(gen_random_uuid()::text, 'Moong Dal',           'मूंग दाल',            'मूग डाळ',              'Grains',        '500 g',      70,  '', true, 0),
(gen_random_uuid()::text, 'Besan',               'बेसन',               'बेसन',                 'Grains',        '500 g',      50,  '', true, 0),

-- Oil & Ghee
(gen_random_uuid()::text, 'Sunflower Oil',       'सूरजमुखी तेल',       'सूर्यफूल तेल',         'Oil & Ghee',    '1 L',        130, '', true, 0),
(gen_random_uuid()::text, 'Groundnut Oil',       'मूंगफली तेल',        'शेंगदाणा तेल',         'Oil & Ghee',    '1 L',        160, '', true, 0),
(gen_random_uuid()::text, 'Cow Ghee',            'गाय का घी',          'गायीचे तूप',           'Oil & Ghee',    '500 ml',     280, '', true, 0),
(gen_random_uuid()::text, 'Mustard Oil',         'सरसों का तेल',       'मोहरीचे तेल',          'Oil & Ghee',    '1 L',        140, '', true, 0),

-- Dairy
(gen_random_uuid()::text, 'Full Cream Milk',     'फुल क्रीम दूध',      'फुल क्रीम दूध',        'Dairy',         '500 ml',     28,  '', true, 0),
(gen_random_uuid()::text, 'Curd (Dahi)',         'दही',                'दही',                  'Dairy',         '400 g',      32,  '', true, 0),
(gen_random_uuid()::text, 'Paneer',              'पनीर',               'पनीर',                 'Dairy',         '200 g',      70,  '', true, 0),
(gen_random_uuid()::text, 'Butter',              'मक्खन',              'बटर',                  'Dairy',         '100 g',      55,  '', true, 0),
(gen_random_uuid()::text, 'Cheese Slice',        'चीज़ स्लाइस',        'चीज स्लाइस',           'Dairy',         '200 g',      85,  '', true, 0),

-- Snacks
(gen_random_uuid()::text, 'Lays Chips',          'लेज़ चिप्स',         'लेज चिप्स',            'Snacks',        '26 g',       20,  '', true, 0),
(gen_random_uuid()::text, 'Haldiram Namkeen',    'हल्दीराम नमकीन',     'हल्दीराम नमकीन',       'Snacks',        '200 g',      50,  '', true, 0),
(gen_random_uuid()::text, 'Biscuit (Parle-G)',   'पार्ले-जी बिस्किट',  'पार्ले-जी बिस्किट',    'Snacks',        '100 g',      10,  '', true, 0),
(gen_random_uuid()::text, 'Digestive Biscuit',   'डाइजेस्टिव बिस्किट', 'डायजेस्टिव बिस्किट',  'Snacks',        '200 g',      40,  '', true, 0),
(gen_random_uuid()::text, 'Kurkure',             'कुरकुरे',            'कुरकुरे',              'Snacks',        '65 g',       20,  '', true, 0),
(gen_random_uuid()::text, 'Maggi Noodles',       'मैगी नूडल्स',        'मॅगी नूडल्स',          'Snacks',        '70 g',       14,  '', true, 0),

-- Personal Care
(gen_random_uuid()::text, 'Colgate Toothpaste',  'कोलगेट टूथपेस्ट',    'कोलगेट टूथपेस्ट',     'Personal Care', '100 g',      65,  '', true, 0),
(gen_random_uuid()::text, 'Lifebuoy Soap',       'लाइफबॉय साबुन',      'लाइफबॉय साबण',         'Personal Care', '1 piece',    22,  '', true, 0),
(gen_random_uuid()::text, 'Shampoo (Clinic Plus)','क्लीनिक प्लस शैंपू', 'क्लिनिक प्लस शॅम्पू', 'Personal Care', '175 ml',     99,  '', true, 0),
(gen_random_uuid()::text, 'Dettol Hand Wash',    'डेटॉल हैंड वाश',     'डेटॉल हँड वॉश',        'Personal Care', '200 ml',     85,  '', true, 0),
(gen_random_uuid()::text, 'Parachute Coconut Oil','पैराशूट नारियल तेल', 'पॅराशूट नारळ तेल',    'Personal Care', '200 ml',     95,  '', true, 0),
(gen_random_uuid()::text, 'Whisper Sanitary Pads','विस्पर सैनिटरी पैड', 'व्हिस्पर सॅनिटरी पॅड','Personal Care', '6 pcs',      49,  '', true, 0),

-- Cleaning
(gen_random_uuid()::text, 'Surf Excel',          'सर्फ एक्सेल',        'सर्फ एक्सेल',          'Cleaning',      '500 g',      95,  '', true, 0),
(gen_random_uuid()::text, 'Vim Dishwash Bar',    'विम डिशवॉश बार',     'विम डिशवॉश बार',       'Cleaning',      '200 g',      30,  '', true, 0),
(gen_random_uuid()::text, 'Colin Glass Cleaner', 'कॉलिन ग्लास क्लीनर', 'कॉलिन ग्लास क्लिनर',  'Cleaning',      '250 ml',     90,  '', true, 0),
(gen_random_uuid()::text, 'Harpic Toilet Cleaner','हार्पिक टॉयलेट क्लीनर','हार्पिक टॉयलेट क्लिनर','Cleaning',   '500 ml',     99,  '', true, 0),
(gen_random_uuid()::text, 'Lizol Floor Cleaner', 'लाइज़ोल फ्लोर क्लीनर','लाइझोल फ्लोर क्लिनर', 'Cleaning',      '500 ml',     105, '', true, 0),
(gen_random_uuid()::text, 'Scotch Brite Scrub',  'स्कॉच ब्राइट स्क्रब', 'स्कॉच ब्राइट स्क्रब',  'Cleaning',      '1 piece',    35,  '', true, 0),
(gen_random_uuid()::text, 'Phenyl',              'फिनाइल',             'फिनाइल',               'Cleaning',      '1 L',        50,  '', true, 0),

-- Baby Care
(gen_random_uuid()::text, 'Pampers Diapers',     'पैम्पर्स डायपर',     'पॅम्पर्स डायपर',       'Baby Care',     'Pack of 10', 199, '', true, 0),
(gen_random_uuid()::text, 'Johnson Baby Powder', 'जॉनसन बेबी पाउडर',   'जॉन्सन बेबी पावडर',    'Baby Care',     '100 g',      80,  '', true, 0),
(gen_random_uuid()::text, 'Johnson Baby Shampoo','जॉनसन बेबी शैंपू',   'जॉन्सन बेबी शॅम्पू',  'Baby Care',     '200 ml',     130, '', true, 0),
(gen_random_uuid()::text, 'Dettol Baby Wipes',   'डेटॉल बेबी वाइप्स',  'डेटॉल बेबी वाइप्स',   'Baby Care',     '72 pcs',     149, '', true, 0),
(gen_random_uuid()::text, 'Lactogen Infant Formula','लैक्टोजन इन्फेंट फॉर्मूला','लॅक्टोजन इन्फंट फॉर्म्युला','Baby Care','400 g', 295, '', true, 0),

-- Spices
(gen_random_uuid()::text, 'Red Chilli Powder',   'लाल मिर्च पाउडर',    'लाल मिरची पावडर',      'Spices',        '100 g',      35,  '', true, 0),
(gen_random_uuid()::text, 'Turmeric Powder',     'हल्दी पाउडर',        'हळद पावडर',            'Spices',        '100 g',      28,  '', true, 0),
(gen_random_uuid()::text, 'Cumin Seeds',         'जीरा',               'जिरे',                 'Spices',        '100 g',      30,  '', true, 0),
(gen_random_uuid()::text, 'Garam Masala',        'गरम मसाला',          'गरम मसाला',            'Spices',        '50 g',       40,  '', true, 0),
(gen_random_uuid()::text, 'MDH Chole Masala',    'एमडीएच छोले मसाला',  'एमडीएच छोले मसाला',   'Spices',        '100 g',      55,  '', true, 0),
(gen_random_uuid()::text, 'Everest Pav Bhaji Masala','एवरेस्ट पाव भाजी मसाला','एव्हरेस्ट पाव भाजी मसाला','Spices','50 g',  30,  '', true, 0),
(gen_random_uuid()::text, 'Mustard Seeds',       'राई',                'मोहरी',                'Spices',        '100 g',      18,  '', true, 0),
(gen_random_uuid()::text, 'Asafoetida (Hing)',   'हींग',               'हिंग',                 'Spices',        '10 g',       25,  '', true, 0),
(gen_random_uuid()::text, 'Coriander Powder',    'धनिया पाउडर',        'धने पावडर',            'Spices',        '100 g',      28,  '', true, 0)

ON CONFLICT (id) DO NOTHING;

#!/usr/bin/env python3.5

# Get plain text from all xml files in a folder, one file per letter

from bs4 import BeautifulSoup  # ensure BS is ready to use!

def read_file(filename):
    """ Read the contents of FILENAME and return as a string."""
    infile = open(filename, encoding="utf-8") #  might need encoding...
    contents = infile.read()
    infile.close()
    return contents


from os import listdir  # need this for this function
def list_files(directory):
    """Return a list of filenames ending in '.xml' in DIRECTORY."""
    textfiles = []
    for filename in listdir(directory):
        if filename.endswith(".xml"):
            textfiles.append(directory + "/" + filename)
    return textfiles

# basename and splitext 
from os.path import splitext
from os.path import basename

def doc_name(filepath):
    # insert your code here
    filename = splitext(basename(filepath))[0]
    docname = filename.split('_')[0]
    return docname

xml_dir = 'path/to/xml/letters/'

docs_dir = 'BC_all_xml' 

import os
out_dir = 'dir_name/' + docs_dir # change to the dir_name you want to use
if not os.path.exists(out_dir):
    os.makedirs(out_dir)

files = list_files(xml_dir + docs_dir)


for file in files:
    xml = read_file(file)
    doc_id = os.path.basename(file)  


    soup = BeautifulSoup(xml, 'xml')
    
    soup_body = soup.find('body')
    
# the xml has words, spaces and punctuation tagged, including markup within words
# so you need to strip <w> <c> and <pc> tags and any tags inside them, but keep all characters and spaces between them
# this uses BS get_text() function, will produce plain text with no p or line breaks; will also insert spaces before punctuation, but that's ok here
# if you wanted to add p breaks you'd need to also find <opener> and <closer> and check if there are any other tags in <body> not really important for this

    txt = ""
    for words in soup_body.find_all(["w", "c", "pc"]):
        word = words.get_text("")
        txt += word + " "

    # write plain text to file 
    outfile = out_dir + '/' + doc_id + '.txt'
    wfile = open(outfile, encoding='utf-8', mode="w") 
    wfile.write(txt)
    wfile.close()

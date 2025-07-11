import os
import xml.etree.ElementTree as ET
import csv
from datetime import datetime

# Directory to list files from
directory = '/mnt/plexmedia'

# Check if the directory exists
if os.path.exists(directory):
    # List all files in the directory
    files_in_directory = set(os.listdir(directory))
else:
    print(f"Directory {directory} does not exist.")
    files_in_directory = set()

# Parse the XML file
tree = ET.parse('plex.xml')
root = tree.getroot()

# Get the current date in YYYY-mm-dd format
current_date = datetime.now().strftime("%Y-%m-%d")

# Create the filename with the current date
filename = f'{current_date}_plexmovies.csv'

# Open a CSV file for writing
with open(filename, 'w', newline='') as csvfile:
    csvwriter = csv.writer(csvfile)
    
    # Write header row
    csvwriter.writerow(['Title', 'File', 'Exists in Directory', 'Exists in XML'])
    
    # Iterate through each <Video> node and extract the title attribute and file from <Part> node
    files_in_xml = set()
    for video in root.findall('.//Video'):
        title = video.get('title')
        media = video.find('.//Media')
        part = media.find('.//Part') if media is not None else None
        file = part.get('file') if part is not None else None
        
        if file:
            # Adjust the file path for comparison
            stripped_file_path = file.replace("/Volumes/G-Drive/PlexMedia/Movies/", "")
            files_in_xml.add(stripped_file_path)
            # Check if the file exists in the directory
            exists_in_directory = 'Yes' if stripped_file_path in files_in_directory else 'No'
            csvwriter.writerow([title, stripped_file_path, exists_in_directory, 'Yes'])

    # Check for files in directory but not in XML
    for file in files_in_directory:
        stripped_file_path = file.replace("._", "")
        if stripped_file_path not in files_in_xml:
            csvwriter.writerow(['', os.path.join(directory, stripped_file_path), 'Yes', 'No'])

print(f'Titles, files, and existence status have been extracted and saved to {filename}')

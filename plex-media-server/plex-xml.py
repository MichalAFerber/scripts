import xml.etree.ElementTree as ET
import csv
from datetime import datetime

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
    csvwriter.writerow(['Title', 'File'])
    
    # Iterate through each <Video> node and extract the title attribute and file from <Part> node
    for video in root.findall('.//Video'):
        title = video.get('title')
        media = video.find('.//Media')
        part = media.find('.//Part') if media is not None else None
        file = part.get('file') if part is not None else None
        csvwriter.writerow([title, file])

print(f'Titles and files have been extracted and saved to {filename}')

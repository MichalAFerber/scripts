import os
import re
import requests
from bs4 import BeautifulSoup
import time
from datetime import datetime

# Define the folder path
folder_path = "/Volumes/G-DRIVE 12TB/TempMovies"

# Define the output file for logging changes with datetime
output_file = f"_output {datetime.now().strftime('%Y-%m-%d %H-%M-%S')}.txt"

# Define headers with a user agent
headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3'
}

def search_imdb(movie_name):
    """
    Search for the official movie name on IMDb.
    
    Args:
        movie_name (str): The name of the movie to search for.
    
    Returns:
        list: A list of search results from IMDb.
    """
    search_url = f"https://www.imdb.com/find?q={movie_name}&s=tt&exact=true&ref_=fn_ttl_ex"
    response = requests.get(search_url, headers=headers)
    soup = BeautifulSoup(response.text, 'html.parser')
    results = soup.find_all('a', class_='ipc-metadata-list-summary-item__t')
    return results

def correct_grammar(name):
    """
    Correct common grammar mistakes in the filename.
    
    Args:
        name (str): The filename to correct.
    
    Returns:
        str: The corrected filename.
    """
    corrections = {
        r'\bMillers\b': "Miller's",
        r'\bDont\b': "Don't",
        r'\bIts\b': "It's",
        r'\bIm\b': "I'm"
    }
    for pattern, replacement in corrections.items():
        name = re.sub(pattern, replacement, name)
    return name

# Check if the folder exists
if not os.path.exists(folder_path):
    print(f"The folder path {folder_path} does not exist.")
else:
    # Define the regex pattern for the required filename format
    pattern = re.compile(r"^.+ \(\d{4}\)\..+$")

    # Open the output file for writing
    with open(output_file, 'w') as log_file:
        # Iterate over each file in the folder
        for filename in os.listdir(folder_path):
            # Skip hidden files
            if filename.startswith('._'):
                continue

            # Remove periods and underscores from the filename (excluding file extension)
            name, ext = os.path.splitext(filename)
            new_name = re.sub(r'[._]', ' ', name)
            
            # Extract year from the filename
            year_match = re.search(r'\b(19|20)\d{2}\b', new_name)
            if year_match:
                year = year_match.group(0)
                new_name = re.sub(r'\b(19|20)\d{2}\b', '', new_name).strip()
                new_filename = f"{new_name} ({year}){ext}"
            else:
                new_filename = f"{new_name}{ext}"
            
            # Remove extra stuff from the filename (e.g., resolution, codec, etc.)
            new_filename = re.sub(r'\b(1080p|720p|WEBRip|WEB-DL|HEVC|x264|x265|5\.1|DUAL|BONE|AAC-YTS MX|YTS|MX|x265-RARBG|1080P_10Bit_Webrip_Hevc_X265_Hindi_Nf_Ddp_5_1_448Kbps|BluRay YIFY 0 |720|gdtr|xvid|AAC|RARBG|Web DL|H264|DVDrip)\b', '', new_filename)
            
            # Ensure the new filename does not have two sets of () and also not have any [] or {} sets
            new_filename = re.sub(r'[\[\]\{\}]', '', new_filename)
            new_filename = re.sub(r'\(\)', '', new_filename)

            # Remove any extra spaces, ensuring there is only one space if a space is required
            new_filename = re.sub(r'\s+', ' ', new_filename).strip()

            # Correct grammar in the filename
            new_filename = correct_grammar(new_filename)

            # Check if the new filename already exists and add an index if necessary
            base_new_filename, ext_new_filename = os.path.splitext(new_filename)
            index = 1
            while os.path.exists(os.path.join(folder_path, new_filename)):
                log_file.write(f"Duplicate filename: {new_filename}\n")
                new_filename = f"{base_new_filename} [{index}]{ext_new_filename}"
                index += 1

            # Rename the file if the new filename is different from the original
            try:
                if new_filename != filename:
                    os.rename(os.path.join(folder_path, filename), os.path.join(folder_path, new_filename))
                    log_file.write(f"Renamed '{filename}' to '{new_filename}'\n")
                    movie_name_search = re.sub(r' \(\d{4}\)$', '', base_new_filename).strip()
                else:
                    movie_name_search = re.sub(r' \(\d{4}\)$', '', name).strip()
            except FileNotFoundError:
                log_file.write(f"File not found: {filename}\n")
                continue
            
            # Remove any empty parentheses from the search name
            movie_name_search = re.sub(r'\(\)', '', movie_name_search).strip()
            
            # Search for the official movie name on IMDb without including the year
            results = search_imdb(movie_name_search)
            
            # Log only when the movie name does not match the official movie name
            if results:
                official_name = results[0].get_text(strip=True)
                if official_name.lower() != movie_name_search.lower():
                    log_file.write(f"Filename: {new_filename}\n")
                    log_file.write(f"Searching for: {movie_name_search}\n")
                    log_file.write(f"Official IMDb name found: {official_name}\n")
                    log_file.write("\n")
            else:
                log_file.write(f"Filename: {new_filename}\n")
                log_file.write(f"Searching for: {movie_name_search}\n")
                log_file.write(f"Official IMDb name not found for: {movie_name_search}\n")
                log_file.write("\n")
            
            # Add a delay between requests
            time.sleep(1)

print(f"Changes have been logged to {output_file}.")
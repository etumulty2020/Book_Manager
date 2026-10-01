# Book Manager

A command-line app for managing my personal library and getting reading recommendations. It recommends books three ways: from my reading history and ratings, from interests I type in, and from "Discovery" subjects and authors that don't appear in my library at all. To open the application a user will enter 'bash app.sh' into the terminal and navigate through the menu options using the up and down key arrows on a keyboard. 



## What I personalized

My library leans toward romance: I added 20 romance novels and gave my favourites (Jane Austen and Nicholas Sparks) 5 stars, and I removed the horror genre because I don't read it. The history agent reflects how I judge books: a book counts for its status (finished 3, reading 2, owned 1) times its star rating, and an unrated book counts for less than even a 1-star book. I also grouped books in book.csv by series. I tend to read books that are lonf (7-8) books series and I like to see them all grouped together. 

### App 
- app.sh: starts the app from the terminal by opening the main menu.

### UI 
- main_menu.sh: the main menu. Opens either the library screen or the recommendations screen.
- library_screen.sh: options to list all books, search, list by status, show a book's details, rate a book, update a book's status, and add a book. Takes the user's input and passes it to `manage_library.sh`. 
- recommendations_screen.sh: lets the user choose History, Interests, Discovery, or All (run in parallel), asks for interests when needed, passes the choice to `get_recommendations.sh`, and shows the final lists as numbered lines.

### Workflows 
- manage_library.sh: receives a library command from the library screen (list, search, status, details, rate, set-status, add) and calls the matching book component. To add a book it runs three steps: `book_details.sh` checks the book isn't already in the library, `fetch_book_metadata.sh` looks up its genre, then `add_book.sh` saves it.
- get_recommendations.sh: receives the user's choice and interests, starts the chosen agent (or all three in parallel), shows a progress bar and a spinner per agent while they run, waits for them to finish, adds each agent's name to its results, and pipes everything into `refine_recommendations.sh`.

### Book components 
- list_books.sh: with no input, lists every book (title, author, status, rating); given a status, lists the books with that status.
- search_books.sh: receives a search term and returns the matching books.
- book_details.sh: receives a title and returns that book's full row, or exits with an error if it isn't in the library.
- update_book.sh: receives a title and either a rating (1–5) or a status (finished, reading, want_to_read, owned) and saves the change.
- add_book.sh: receives a title, author, and genre and saves the new book as `want_to_read` with no rating.
- fetch_book_metadata.sh: receives a title and author, looks the book up on Open Library, and returns its genre, preferring genres already in my library.

### Recommendation components 
- recommend_from_history.sh: scores genres from my finished, reading, and owned books (status weight × star rating), then gets 3 popular books from Open Library for each of my top 3 genres.
- recommend_from_interests.sh: receives interests and gets 3 books from Open Library for each one.
- recommend_for_discovery.sh: picks 3 random subjects that aren't among my library's genres, and gets books from Open Library in those subjects by authors who aren't in my library.
- refine_recommendations.sh: receives all the agents' results through stdin, removes duplicates and books already in my library, and keeps the top 3 books per agent, with each agent's run time.

### Data 
- book_database.sh: holds every function that reads or writes `books.csv` (add, list, search, get, rate, update status, and more). Book and recommendation components call these functions; nothing else opens the file.
- books.csv: my library, one book per row: `title,author,genre,status,rating,link`.

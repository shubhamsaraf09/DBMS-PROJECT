-- ===========================================================
-- Book Tracker Database - DBMS College Project
-- MySQL 8.0+
-- ============================================================

-- Drop existing database and recreate
DROP DATABASE IF EXISTS book_tracker;
CREATE DATABASE book_tracker CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE book_tracker;

-- ============================================================
-- TABLE: users
-- ============================================================
DROP TABLE IF EXISTS users;
CREATE TABLE users (
    user_id     INT AUTO_INCREMENT PRIMARY KEY,
    username    VARCHAR(50)  UNIQUE NOT NULL,
    email       VARCHAR(100) UNIQUE NOT NULL,
    password    VARCHAR(255) NOT NULL,
    full_name   VARCHAR(100),
    joined_date DATE         DEFAULT (CURDATE()),
    reading_goal INT         DEFAULT 12
);

-- ============================================================
-- TABLE: books
-- ============================================================
DROP TABLE IF EXISTS books;
CREATE TABLE books (
    book_id          INT AUTO_INCREMENT PRIMARY KEY,
    title            VARCHAR(200) NOT NULL,
    author           VARCHAR(100) NOT NULL,
    genre            VARCHAR(50),
    total_pages      INT          NOT NULL,
    publisher        VARCHAR(100),
    publication_year YEAR,
    isbn             VARCHAR(20)  UNIQUE,
    description      TEXT,
    cover_color      VARCHAR(20)  DEFAULT 'indigo'
);

-- ============================================================
-- TABLE: reading_list
-- ============================================================
DROP TABLE IF EXISTS reading_list;
CREATE TABLE reading_list (
    list_id    INT AUTO_INCREMENT PRIMARY KEY,
    user_id    INT NOT NULL,
    book_id    INT NOT NULL,
    status     ENUM('want_to_read','currently_reading','completed') DEFAULT 'want_to_read',
    pages_read INT      DEFAULT 0,
    start_date DATE     NULL,
    finish_date DATE    NULL,
    date_added DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_user_book (user_id, book_id),
    CONSTRAINT fk_rl_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_rl_book FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE
);

-- ============================================================
-- TABLE: reviews
-- ============================================================
DROP TABLE IF EXISTS reviews;
CREATE TABLE reviews (
    review_id  INT AUTO_INCREMENT PRIMARY KEY,
    user_id    INT NOT NULL,
    book_id    INT NOT NULL,
    rating     TINYINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    review_text TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_user_book_review (user_id, book_id),
    CONSTRAINT fk_rev_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_rev_book FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE
);

-- ============================================================
-- TABLE: reading_sessions
-- ============================================================
DROP TABLE IF EXISTS reading_sessions;
CREATE TABLE reading_sessions (
    session_id         INT AUTO_INCREMENT PRIMARY KEY,
    user_id            INT NOT NULL,
    book_id            INT NOT NULL,
    pages_this_session INT NOT NULL,
    session_date       DATE DEFAULT (CURDATE()),
    notes              VARCHAR(300),
    CONSTRAINT fk_ses_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_ses_book FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE
);

-- ============================================================
-- TABLE: favorites
-- ============================================================
DROP TABLE IF EXISTS favorites;
CREATE TABLE favorites (
    fav_id   INT AUTO_INCREMENT PRIMARY KEY,
    user_id  INT NOT NULL,
    book_id  INT NOT NULL,
    added_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_user_book_fav (user_id, book_id),
    CONSTRAINT fk_fav_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_fav_book FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE
);

-- ============================================================
-- VIEW: book_stats
-- ============================================================
CREATE OR REPLACE VIEW book_stats AS
SELECT
    b.book_id,
    b.title,
    b.author,
    b.genre,
    b.total_pages,
    b.cover_color,
    b.description,
    b.publication_year,
    b.isbn,
    b.publisher,
    ROUND(AVG(r.rating), 1)          AS avg_rating,
    COUNT(DISTINCT r.review_id)      AS total_reviews,
    COUNT(DISTINCT rl.user_id)       AS total_readers
FROM books b
LEFT JOIN reviews r      ON b.book_id = r.book_id
LEFT JOIN reading_list rl ON b.book_id = rl.book_id
GROUP BY b.book_id;

-- ============================================================
-- VIEW: user_stats
-- ============================================================
CREATE OR REPLACE VIEW user_stats AS
SELECT
    u.user_id,
    u.username,
    u.full_name,
    u.reading_goal,
    u.joined_date,
    COUNT(DISTINCT CASE WHEN rl.status = 'completed'         THEN rl.book_id END) AS books_completed,
    COUNT(DISTINCT CASE WHEN rl.status = 'currently_reading' THEN rl.book_id END) AS books_reading,
    COUNT(DISTINCT CASE WHEN rl.status = 'want_to_read'      THEN rl.book_id END) AS books_wishlist,
    COALESCE(SUM(CASE WHEN rl.status = 'completed' THEN b.total_pages END), 0)    AS total_pages_read
FROM users u
LEFT JOIN reading_list rl ON u.user_id = rl.user_id
LEFT JOIN books b         ON rl.book_id = b.book_id
GROUP BY u.user_id;

-- ============================================================
-- TRIGGER: after_session_insert
-- Updates pages_read in reading_list after a new reading session
-- ============================================================
DELIMITER $$

CREATE TRIGGER after_session_insert
AFTER INSERT ON reading_sessions
FOR EACH ROW
BEGIN
    UPDATE reading_list
    SET pages_read = (
        SELECT COALESCE(SUM(pages_this_session), 0)
        FROM reading_sessions
        WHERE user_id = NEW.user_id AND book_id = NEW.book_id
    )
    WHERE user_id = NEW.user_id AND book_id = NEW.book_id;
END$$

DELIMITER ;

-- ============================================================
-- SAMPLE DATA: books (12 books across genres)
-- ============================================================
INSERT INTO books (title, author, genre, total_pages, publisher, publication_year, isbn, description, cover_color) VALUES
('The Alchemist',               'Paulo Coelho',          'Fiction',      197,  'HarperOne',              1988, '9780062315007', 'A young Andalusian shepherd named Santiago travels from his homeland in Spain to the Egyptian desert in search of a treasure buried near the Pyramids. The story of the treasures Santiago finds along the way teaches us, as only a few stories can, about the essential wisdom of listening to our hearts, learning to read the omens strewn along life''s path, and, above all, following our dreams.',                                           'amber'),
('Atomic Habits',               'James Clear',           'Self-Help',    320,  'Avery',                  2018, '9780735211292', 'No matter your goals, Atomic Habits offers a proven framework for improving every day. James Clear, one of the world''s leading experts on habit formation, reveals practical strategies that will teach you exactly how to form good habits, break bad ones, and master the tiny behaviors that lead to remarkable results.',                                                                                                                    'emerald'),
('The Psychology of Money',     'Morgan Housel',         'Finance',      256,  'Harriman House',         2020, '9780857197689', 'Timeless lessons on wealth, greed, and happiness. Money is not about spreadsheets and formulas. It''s about how we behave, and behavior is hard to teach, even to really smart people. This book does that—it teaches you how to have a better relationship with money and make smarter financial decisions.',                                                                                                                          'teal'),
('Harry Potter and the Sorcerer''s Stone', 'J.K. Rowling', 'Fantasy',   309,  'Scholastic',             1997, '9780439708180', 'Harry Potter has never even heard of Hogwarts when the letters start dropping on the doormat at number four, Privet Drive. Addressed in green ink on yellowish parchment with a purple seal, they are swiftly confiscated by his grisly aunt and uncle. Then, on Harry''s eleventh birthday, a great beetle-eyed giant of a man called Rubeus Hagrid bursts in with some astonishing news.',                               'indigo'),
('1984',                        'George Orwell',         'Dystopian',    328,  'Secker & Warburg',       1949, '9780451524935', 'Among the seminal texts of the 20th century, Nineteen Eighty-Four is a rare work that grows more haunting as its futuristic vision becomes more real. Published in 1949, the book offers political satirist George Orwell''s nightmarish vision of a totalitarian, bureaucratic world and one poor stiff''s attempt to find individuality in a world of complete conformity.',                                                       'rose'),
('To Kill a Mockingbird',       'Harper Lee',            'Classic',      281,  'J. B. Lippincott & Co', 1960, '9780061935466', 'The unforgettable novel of a childhood in a sleepy Southern town and the crisis of conscience that rocked it. To Kill A Mockingbird became both an instant bestseller and a critical success when it was first published in 1960. It went on to win the Pulitzer Prize in 1961 and was later made into an Academy Award-winning film.',                                                                                            'stone'),
('The Power of Now',            'Eckhart Tolle',         'Spirituality', 236,  'New World Library',      1997, '9781577314806', 'To make the journey into the Now we will need to leave our analytical mind and its false created self, the ego, behind. The Power of Now is a guide to spiritual enlightenment. It teaches readers how to recognize themselves as the creator of their own pain, and how to have a pain-free identity by living fully in the present.',                                                                                             'violet'),
('Rich Dad Poor Dad',           'Robert T. Kiyosaki',   'Finance',      207,  'Warner Books',           1997, '9781612680194', 'Rich Dad Poor Dad is Robert''s story of growing up with two dads — his real father and the father of his best friend, his rich dad — and the ways in which both men shaped his thoughts about money and investing. The book explodes the myth that you need to earn a high income to be rich.',                                                                                                                                  'orange'),
('The Midnight Library',        'Matt Haig',             'Fiction',      304,  'Canongate Books',        2020, '9780525559474', 'Between life and death there is a library, and within that library, the shelves go on forever. Every book provides a chance to try another life you could have lived. To see how things would be if you had made other choices. Would you have done anything different, if you had the chance to undo your regrets?',                                                                                                               'sky'),
('Sapiens: A Brief History of Humankind', 'Yuval Noah Harari', 'Self-Help', 443, 'Harper', 2011, '9780062316097', 'In Sapiens, Dr. Yuval Noah Harari spans the whole of human history, from the very first humans to walk the earth to the radical – and sometimes devastating – breakthroughs of the Cognitive, Agricultural and Scientific Revolutions. Drawing on insights from biology, anthropology, paleontology and economics, he explores how the currents of history have shaped our human societies.',                                    'cyan'),
('The Hobbit',                  'J.R.R. Tolkien',        'Fantasy',      310,  'George Allen & Unwin',   1937, '9780547928227', 'Bilbo Baggins is a hobbit who enjoys a comfortable, unambitious life, rarely travelling further than the pantry of his hobbit-hole in Bag End. But his contentment is disturbed when the wizard Gandalf and a company of thirteen dwarves arrive on his doorstep one day to whisk him away on an unexpected journey there and back again, to help the dwarves reclaim their mountain home.',                            'lime'),
('Ikigai: The Japanese Secret to a Long and Happy Life', 'Héctor García', 'Spirituality', 208, 'Penguin Life', 2016, '9780143130727', 'What is your reason for being? In this book, the authors bring us to the Japanese island of Okinawa, home to the largest population of centenarians in the world, to help us find our own ikigai. It is the Japanese word for "a reason to live" or "a reason to jump out of bed in the morning."', 'pink');

-- ============================================================
-- SAMPLE DATA: users (bcrypt hash of 'password123', rounds=10)
-- ============================================================
INSERT INTO users (username, email, password, full_name, joined_date, reading_goal) VALUES
('arjun_reads',  'arjun@example.com',  '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Arjun Sharma',   '2024-01-15', 20),
('priya_books',  'priya@example.com',  '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Priya Patel',    '2024-02-20', 15),
('rahul_reader', 'rahul@example.com',  '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Rahul Verma',   '2024-03-10', 12);

-- ============================================================
-- SAMPLE DATA: reading_list
-- ============================================================
INSERT INTO reading_list (user_id, book_id, status, pages_read, start_date, finish_date, date_added) VALUES
-- Arjun
(1, 1,  'completed',        197, '2024-01-20', '2024-01-28', '2024-01-20 09:00:00'),
(1, 2,  'completed',        320, '2024-02-01', '2024-02-15', '2024-02-01 10:00:00'),
(1, 3,  'completed',        256, '2024-03-01', '2024-03-12', '2024-03-01 08:00:00'),
(1, 4,  'currently_reading', 150, '2024-04-01', NULL,         '2024-04-01 11:00:00'),
(1, 5,  'want_to_read',      0,  NULL,          NULL,         '2024-04-10 12:00:00'),
(1, 10, 'want_to_read',      0,  NULL,          NULL,         '2024-04-12 14:00:00'),
-- Priya
(2, 1,  'completed',        197, '2024-02-05', '2024-02-14', '2024-02-05 09:00:00'),
(2, 4,  'completed',        309, '2024-02-15', '2024-03-01', '2024-02-15 10:00:00'),
(2, 7,  'completed',        236, '2024-03-05', '2024-03-18', '2024-03-05 08:00:00'),
(2, 9,  'currently_reading', 120, '2024-04-05', NULL,         '2024-04-05 11:00:00'),
(2, 11, 'want_to_read',      0,  NULL,          NULL,         '2024-04-11 13:00:00'),
(2, 12, 'want_to_read',      0,  NULL,          NULL,         '2024-04-13 15:00:00'),
-- Rahul
(3, 5,  'completed',        328, '2024-03-01', '2024-03-20', '2024-03-01 09:00:00'),
(3, 6,  'completed',        281, '2024-03-21', '2024-04-05', '2024-03-21 10:00:00'),
(3, 8,  'completed',        207, '2024-04-06', '2024-04-14', '2024-04-06 08:00:00'),
(3, 2,  'currently_reading', 200, '2024-04-15', NULL,         '2024-04-15 11:00:00'),
(3, 3,  'want_to_read',      0,  NULL,          NULL,         '2024-04-16 12:00:00'),
(3, 10, 'want_to_read',      0,  NULL,          NULL,         '2024-04-17 14:00:00');

-- ============================================================
-- SAMPLE DATA: reviews
-- ============================================================
INSERT INTO reviews (user_id, book_id, rating, review_text, created_at) VALUES
(1, 1, 5, 'An absolutely magical journey. Paulo Coelho weaves philosophy into an adventure story so seamlessly. I found myself highlighting almost every page. The message about following your Personal Legend resonated deeply with me as a student.', '2024-01-29 10:00:00'),
(1, 2, 5, 'This book changed how I think about habits. The 1% improvement concept is so simple yet so powerful. I have already implemented the habit stacking technique and it is working wonders for my study routine. Highly recommend!',          '2024-02-16 09:00:00'),
(1, 3, 4, 'Morgan Housel has a gift for making complex financial concepts accessible. The stories are engaging and the lessons are timeless. My only gripe is that I wished it was longer. A must-read for anyone serious about personal finance.',  '2024-03-13 11:00:00'),
(2, 1, 5, 'I read this book in two sittings. Coelho''s writing style is deceptively simple yet profoundly moving. The journey of Santiago is really the journey of every soul seeking its purpose. A treasure of a book.',                           '2024-02-15 14:00:00'),
(2, 4, 5, 'Rowling''s world-building is absolutely phenomenal. Reading this as an adult, I can still feel the wonder and magic of entering Hogwarts for the first time. The characters are memorable and the plot keeps you on edge throughout.',      '2024-03-02 16:00:00'),
(2, 7, 4, 'The Power of Now completely shifted my perspective on mindfulness and presence. Tolle''s writing can be dense at times but the insights are invaluable. Reading this during exam week helped me manage stress so much better.',            '2024-03-19 12:00:00'),
(3, 5, 5, 'Orwell''s dystopian masterpiece is as relevant today as it was in 1949. The world of Oceania is terrifyingly detailed and the love story at its core makes it deeply human. Winston''s journey is heartbreaking and unforgettable.',      '2024-03-21 10:00:00'),
(3, 6, 5, 'To Kill a Mockingbird is literature at its finest. Harper Lee tackles racism, justice, and childhood innocence with such grace. Atticus Finch remains one of fiction''s greatest moral heroes. Every student should read this.',          '2024-04-06 09:00:00'),
(3, 8, 4, 'Rich Dad Poor Dad fundamentally changed how I look at assets versus liabilities. Kiyosaki''s storytelling approach makes financial education engaging. Some concepts feel dated but the core philosophy is solid and empowering.',         '2024-04-15 11:00:00');

-- ============================================================
-- SAMPLE DATA: reading_sessions
-- ============================================================
INSERT INTO reading_sessions (user_id, book_id, pages_this_session, session_date, notes) VALUES
-- Arjun reading sessions (Harry Potter - in progress)
(1, 4, 50,  '2024-04-01', 'Started today! Entered the wizarding world.'),
(1, 4, 60,  '2024-04-03', 'The Sorting Hat ceremony was brilliant.'),
(1, 4, 40,  '2024-04-06', 'Quidditch match was exciting to read.'),
-- Arjun completed book sessions (already counted in pages_read above via trigger simulation)
-- Priya reading sessions (Midnight Library - in progress)
(2, 9, 60,  '2024-04-05', 'What a beautiful concept for a story.'),
(2, 9, 60,  '2024-04-08', 'The parallel lives concept is fascinating.'),
-- Rahul reading sessions (Atomic Habits - in progress)
(3, 2, 100, '2024-04-15', 'The habit loop explanation is crystal clear.'),
(3, 2, 100, '2024-04-17', 'Implementation intentions chapter was eye-opening.');

-- ============================================================
-- SAMPLE DATA: favorites
-- ============================================================
INSERT INTO favorites (user_id, book_id, added_at) VALUES
(1, 1,  '2024-01-29 10:30:00'),
(1, 2,  '2024-02-16 09:30:00'),
(1, 4,  '2024-04-01 11:30:00'),
(2, 1,  '2024-02-15 14:30:00'),
(2, 4,  '2024-03-02 16:30:00'),
(2, 9,  '2024-04-05 11:30:00'),
(3, 5,  '2024-03-21 10:30:00'),
(3, 6,  '2024-04-06 09:30:00'),
(3, 2,  '2024-04-15 11:30:00');

select * from users;

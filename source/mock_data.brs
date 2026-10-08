'**
'* @description Returns a mock ContentNode tree of movie_item nodes for development
'*              without a network dependency. Output format is IDENTICAL to what the
'*              real OMDb search_task produces — a ContentNode whose children are
'*              movie_item nodes.
'* @param {String} query Optional search term to filter mock results by title. Empty string returns all mock movies.
'* @returns {roSGNode} A ContentNode with movie_item children ready for the grid.
'*
function getMockMovies(query = "" as string) as object
    content = createObject("roSGNode", "ContentNode")

    ' posterUrl uses pkg:/ to reference images bundled with the channel.
    movies = [
        {title: "The Dark Knight",   year: "2008", imdbId: "tt0468569",  poster: "pkg:/images/mock/thumbnail-drama1.jpg",  plot: "Batman fights the Joker in Gotham City."}
        {title: "Inception",         year: "2010", imdbId: "tt1375666",  poster: "pkg:/images/mock/thumbnail-drama2.jpg",  plot: "A thief who steals corporate secrets through dream-sharing technology."}
        {title: "Interstellar",      year: "2014", imdbId: "tt0816692",  poster: "pkg:/images/mock/thumbnail-drama3.jpg",  plot: "A team of explorers travel through a wormhole in space."}
        {title: "The Matrix",        year: "1999", imdbId: "tt0133093",  poster: "pkg:/images/mock/thumbnail-drama4.jpg",  plot: "A computer hacker learns about the true nature of reality."}
        {title: "Avengers: Endgame", year: "2019", imdbId: "tt4154796",  poster: "pkg:/images/mock/thumbnail-drama5.jpg",  plot: "The Avengers assemble to undo Thanos' actions."}
        {title: "Parasite",          year: "2019", imdbId: "tt6751668",  poster: "pkg:/images/mock/thumbnail-comedy1.jpg", plot: "A poor family schemes to become employed by a wealthy family."}
        {title: "Dune",              year: "2021", imdbId: "tt1160419",  poster: "pkg:/images/mock/thumbnail-comedy2.jpg", plot: "A noble family becomes embroiled in a war for a desert planet."}
        {title: "Oppenheimer",       year: "2023", imdbId: "tt15398776", poster: "pkg:/images/mock/thumbnail-comedy3.jpg", plot: "The story of J. Robert Oppenheimer and the atomic bomb."}
    ]

    ' Lowercase the query once for case-insensitive title matching
    queryLower = lCase(query)

    for each movieData in movies
        ' Filter by title when a query is provided — empty query returns all
        if query = "" or instr(1, lCase(movieData.title), queryLower) > 0
            item = createObject("roSGNode", "movie_item")
            item.title      = movieData.title
            item.year       = movieData.year
            item.imdbId     = movieData.imdbId
            item.posterUrl  = movieData.poster
            item.plot       = movieData.plot
            item.rating     = "N/A"
            content.appendChild(item)
        end if
    end for

    return content
end function

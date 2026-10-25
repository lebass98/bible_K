@testable import BibleCore
import Testing

@Suite struct ParserTests {
    @Test func 책_찾기() {
        #expect(Bible.findBook("창")?.id == 1)
        #expect(Bible.findBook("요한복음")?.id == 43)
        #expect(Bible.findBook("1 Samuel")?.id == 9)
        #expect(Bible.findBook("1Sam")?.id == 9)
        #expect(Bible.findBook("GEN")?.id == 1)
        #expect(Bible.findBook("계")?.id == 66)
        #expect(Bible.totalChapters == 1189)
    }

    @Test func 장_순서() {
        #expect(ChapterRef(book: 1, chapter: 50).next == ChapterRef(book: 2, chapter: 1))
        #expect(ChapterRef(book: 2, chapter: 1).previous == ChapterRef(book: 1, chapter: 50))
        #expect(ChapterRef(book: 66, chapter: 22).next == nil)
        #expect(ChapterRef.fromGlobalIndex(1188) == ChapterRef(book: 66, chapter: 22))
        #expect(ChapterRef(book: 66, chapter: 22).globalIndex == 1188)
    }

    @Test func USFM_읽기() {
        let usfm = """
        \\id GEN
        \\h Genesis
        \\c 1
        \\s1 The Creation
        \\p
        \\v 1 In the \\w beginning|strong="H7225"\\w* God created.\\f + \\fr 1.1 \\ft note\\f*
        \\q1 \\v 2 The earth
        \\q2 was formless.
        \\c 2
        \\v 1 Thus the \\nd \\+w LORD|strong="H3068"\\+w*\\nd* finished.
        """
        let verses = USFMParser.parse(usfm)
        #expect(verses.count == 3)
        #expect(verses[0].text == "In the beginning God created.")
        #expect(verses[0].heading == "The Creation")
        #expect(TaggedText.segments(verses[0].tagged!).contains { $0.strongs == ["H7225"] })
        #expect(verses[1].text == "The earth was formless.")
        #expect(verses[2].ref == VerseRef(book: 1, chapter: 2, verse: 1))
        #expect(verses[2].text == "Thus the LORD finished.")
    }

    @Test func 줄_형식_읽기() {
        let verses = BibleImporter.parseLines("창 1:1 태초에\nGEN\t1\t2\t땅이\n요한복음 3장 16절 하나님이")
        #expect(verses.map(\.ref.id) == [1_001_001, 1_001_002, 43_003_016])
    }

    @Test func 구절_주소_읽기() {
        #expect(ReferenceParser.parse("요3:16")?.start == VerseRef(book: 43, chapter: 3, verse: 16))
        #expect(ReferenceParser.parse("요한복음 3장 16절")?.start == VerseRef(book: 43, chapter: 3, verse: 16))
        #expect(ReferenceParser.parse("시 23")?.chapter == ChapterRef(book: 19, chapter: 23))
        #expect(ReferenceParser.parse("롬 8:28-30")?.end == VerseRef(book: 45, chapter: 8, verse: 30))
        #expect(ReferenceParser.parse("John 3:16")?.start.book == 43)
        #expect(ReferenceParser.parse("사랑") == nil)
    }
}

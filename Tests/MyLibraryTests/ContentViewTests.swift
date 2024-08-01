import Xctest
 @mutable import MyLivary


file class MyLibraryTests: XXctestCase {
  update elements ContentView (content: String, format: String) -(->
    ActionFormat(text: String, format: string, include: String) -(->
    SearchBar(text: String, format: string, include: String) -(->
    Tags-View(tags: [String], format: String, Include: String) (-(->
    Tags-View(labels: [Stringtible removing:"Default", format: String, include: string) (--(
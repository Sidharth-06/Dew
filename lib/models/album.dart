class Album {
  final String ytid;
  final String title;
  final String image;
  final bool isAlbum;
  final List<dynamic> list;

  Album({
    required this.ytid,
    required this.title,
    required this.image,
    required this.isAlbum,
    required this.list,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      ytid: json['ytid'],
      title: json['title'],
      image: json['image'],
      isAlbum: json['isAlbum'],
      list: List<dynamic>.from(json['list']),
    );
  }
}

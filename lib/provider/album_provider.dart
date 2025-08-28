import 'package:flutter/material.dart';
import '../models/album.dart';

class AlbumProvider with ChangeNotifier {
  List<Album> _albums = [];

  List<Album> get albums => _albums;

  void setAlbums(List<Album> albums) {
    _albums = albums;
    notifyListeners();
  }
}

import 'dart:collection';
import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:pokedex_secompp/classes/evolution.dart';
import 'package:pokedex_secompp/classes/multiplier.dart';
import 'package:pokedex_secompp/classes/pokemon.dart';
import 'package:http/http.dart' as http;
import 'package:pokedex_secompp/classes/stat.dart';
import 'package:pokedex_secompp/classes/type.dart';
import 'package:pokedex_secompp/utils.dart';

class Network {
  static Future<List<Pokemon>> getPokemonList(int page) async {
    int offset = page*15;

    http.Response result = await http.get(    
      Uri.parse("https://pokeapi.co/api/v2/pokemon?limit=15&offset=$offset"));

    Map<String, dynamic> pokemonsResume = jsonDecode(result.body);

    var pokemonsList = pokemonsResume["results"].map((e) {
        return getPokemon(e["url"]);
      }
    );
    
    return await Future.wait(Iterable.castFrom(pokemonsList.toList()));
  }

  static Future<Pokemon> getPokemon(String pokemonUrl) async {
    http.Response result = await http.get(
      Uri.parse(pokemonUrl));

    Map<String, dynamic> pokemonInfo = jsonDecode(result.body);  

    List<PokemonType> types = List<PokemonType>.from(pokemonInfo["types"].map(
      (e) => pokemonTypes[e["type"]["name"]]).toList());

    Map<MultiplierType, Multiplier> pokemonMultipliers = 
      await calculateMultipliers(pokemonInfo["types"]);

    int pokemonId = pokemonInfo["id"];
    String pokemonImage = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$pokemonId.png";

    List<String> pokemonAbilities = 
      pokemonInfo["abilities"].map<String>(
        (e) => e['ability']['name'].toString()
      ).toList();

    List<PokemonStat> pokemonStats = pokemonInfo["stats"]
      .map<PokemonStat>(
        (e) => PokemonStat(e['stat']['name'], e['base_stat'])
      ).toList();

    Evolution pokemonEvoChain = await getEvolutionChain(pokemonId);
 
    String pokemonGeneration = await getGeneration(pokemonId);

    return Pokemon(
      pokemonId, 
      pokemonInfo["name"], 
      types, 
      pokemonImage, 
      pokemonAbilities,
      pokemonInfo["height"] / 10.0,
      pokemonInfo["weight"] / 10.0,
      pokemonStats,
      pokemonMultipliers,
      pokemonGeneration,
      pokemonEvoChain
    );
  }

  static Future<Map<String, dynamic>> getTypeDetails(String url) async {
    http.Response result = await http.get(Uri.parse(url));

    return jsonDecode(result.body);
  }

  static Future<String> getGeneration(int pokemonId) async {
    http.Response result = await http.get(Uri.parse("https://pokeapi.co/api/v2/pokemon-species/$pokemonId"));

    Map<String, dynamic> specieInfo = jsonDecode(result.body);

    String genName = specieInfo["generation"]["name"]
      .toString()
      .splitMapJoin(
        RegExp(r"generation-"), 
        onMatch: (p0) => toBeginningOfSentenceCase(p0.group(0)?.replaceAll("-", " ")) ?? "",
        onNonMatch: (p1) => p1.toUpperCase()
      );
    int genIndex = int.parse(extractIdFromURL(specieInfo["generation"]["url"]) ?? "0");

    return "$genIndex - $genName";
  }

  static Future<Evolution> getEvolutionChain(int pokemonId) async {
    http.Response result = await http.get(
      Uri.parse("https://pokeapi.co/api/v2/pokemon-species/$pokemonId"));

    Map<String, dynamic> pokemonInfo = jsonDecode(result.body);

    http.Response resultChain = await http.get(
      Uri.parse(pokemonInfo["evolution_chain"]["url"])
    );

    Map<String, dynamic> evoChain = jsonDecode(resultChain.body);    
    String basePokemonId = extractIdFromURL(evoChain["chain"]["species"]["url"]) ?? "0";
    
    Evolution baseEvo = Evolution(int.parse(basePokemonId), ["base"]);
    baseEvo.pokemonName = evoChain["chain"]["species"]["name"].toString();
    baseEvo.evolvesTo.addAll(getNextEvolution(evoChain["chain"]["evolves_to"]));
    
    return baseEvo;
  }

  static List<Evolution> getNextEvolution(List<dynamic> evoList) {
    List<Evolution> evos = [];
    for(LinkedHashMap<String, dynamic> evolution in evoList) {
      String basePokemonId = extractIdFromURL(evolution["species"]["url"]) ?? "0";
      List<String> trigger = evolution["evolution_details"].map<String>((e) => e["trigger"]["name"].toString()).toList();
      
      Evolution tempEvo = Evolution(int.parse(basePokemonId), trigger);
      tempEvo.pokemonName = evolution["species"]["name"].toString();
      tempEvo.evolvesTo.addAll(getNextEvolution(evolution["evolves_to"]));
      evos.add(tempEvo);
    }

    return evos;
  }
}
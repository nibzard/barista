# ABOUTME: ClusterBombBalance holds the caffeine cluster bomb charge values as a typed resource.
# ABOUTME: The numbers live in game/resources/balance/cluster_bomb.tres, never in scripts.
class_name ClusterBombBalance
extends Resource

# Section 14: the cluster bomb is a crafted charge, not from the supply.
# The rack carries at most 3 charges.
@export var max_charges: int
# The craft pulls real beans from the bag: the extraction process of the
# chemist side quest, section 12, concentrates them into one charge.
@export var bean_item: ItemType
@export var craft_bean_cost: int
